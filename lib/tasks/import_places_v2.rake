require Rails.root.join("lib/distance_helper_v2_new")
require Rails.root.join("lib/peace_quiet_v2_new")

CATEGORIES_V2 = {
  "convenience_store" => { max: 5, score: :proximity },
  "supermarket" => { max: 5, score: :proximity },
  "atm" => { max: 5, score: :proximity },
  "cafe" => { max: 10, score: :density },
  "restaurant" => { max: 10, score: :density },
  "bar" => { max: 10, score: :density },
  "park" => { max: 5, score: :park_hybrid, primary: true }, # primary-type only: excludes smoking areas / squares
  "gym" => { max: 5, score: :proximity },
  "tourist_attraction" => { max: 10, score: :density },
  # transit_station is Google's GENERIC transit type — it also returns bus stops, which in Japan are
  # named after nearby landmarks (e.g. a "Otori-jinja Shrine" bus stop ranks above the real station).
  # `types` overrides the API query to rail-only; the stored category + score_inputs key stay
  # "transit_station" so the scorer/verify/spec are unaffected.
  # photo: false — stations don't carry a useful photo (and the user only wants photos for the 9 POIs).
  "transit_station" => { max: 1, score: :station, types: %w[subway_station train_station], photo: false }
}.freeze

SEARCH_NEARBY_URL = "https://places.googleapis.com/v1/places:searchNearby".freeze
COMPUTE_ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes".freeze
PLACES_FIELD_MASK = "places.id,places.displayName,places.location,places.rating".freeze

namespace :places do
  desc <<~DESC
    Import nearby places per property/category via the Places API (New). Args: [property_id,category]

    Both args are optional. Omit property_id to run all properties. Omit category to fetch all 10.
    Example: rake "places:import_v2[479,atm]"             — 1 API call.
    Example: rake "places:import_v2[479,transit_station]"  — nearest station only.

    Walking time to station requires ROUTES_API to be set in .env. If absent, the station Place
    row is still saved but time_to_station in score_inputs will be nil.

    A bare `rake places:import_v2` (no args) is GAP-FILL: it skips properties that already have v2
    places, so it is safe to re-run and only imports newly-added properties. A specific property_id
    (or a category) always imports — so to refresh an existing property, destroy its places first.

    WARNING: Targeting a property that already has v2 places creates duplicate rows. score_inputs is
    computed from all current rows, so duplicates over-saturate density signals. Delete the
    property's places before re-importing it.

      # To re-import for a single property cleanly:
      # property.places.destroy_all
      # rake places:import_v2[property_id]
  DESC
  task :import_v2, %i[property_id category] => :environment do |_t, args|
    places_key = ENV.fetch("PLACES_API_V2") do
      abort "PLACES_API_V2 is not set. Export your Google Places API (New) key first."
    end
    routes_key = ENV.fetch("ROUTES_API", nil)

    scope = args[:property_id].present? ? Property.where(id: args[:property_id]) : Property.all

    # Gap-fill: a bare bulk run (no property_id and no category) skips properties that already have
    # v2 places — so it never duplicates and only imports newly-added properties. A targeted run
    # always imports (destroy a property's places first to refresh it).
    gap_fill = args[:property_id].blank? && args[:category].blank?
    skipped = 0

    categories =
      if args[:category].present?
        filtered = CATEGORIES_V2.slice(args[:category])
        abort "Unknown category #{args[:category].inspect}. Valid: #{CATEGORIES_V2.keys.join(', ')}" if filtered.empty?
        filtered
      else
        CATEGORIES_V2
      end

    scope.find_each do |property|
      if gap_fill && property.places.exists?
        skipped += 1
        next
      end

      fetched = 0

      ActiveRecord::Base.transaction do
        categories.each do |category, config|
          fetched += fetch_and_persist_category(property, category, config, places_key)
          sleep 0.15
        end

        station = property.places.where(category: "transit_station").order(:distance_meters).first
        walking_minutes = resolve_walking_minutes(property, station, routes_key)
        property.update!(score_inputs: build_score_inputs_v2(property, walking_minutes))
      end

      puts "Property #{property.id} (#{property.name}): #{categories.size} categories, #{fetched} places fetched."
    rescue StandardError => e
      warn "!! Property #{property.id} (#{property.name}) FAILED: #{e.class}: #{e.message}"
      next
    end

    puts "Skipped #{skipped} property(ies) that already had v2 places (gap-fill)." if gap_fill && skipped.positive?
  end

  def fetch_and_persist_category(property, category, config, places_key)
    types = config[:types] || [category] # per-category API-type override (see transit_station)
    # config[:primary] uses includedPrimaryTypes — matches only places whose MAIN type is the category
    # (so a square / smoking area that merely also carries "park" is excluded). Default is the looser
    # includedTypes, which we WANT for e.g. restaurants (primary is a cuisine type) and ATMs (often
    # primarily a bank/convenience_store).
    body = {
      (config[:primary] ? :includedPrimaryTypes : :includedTypes) => types,
      maxResultCount: config[:max],
      rankPreference: "DISTANCE",
      locationRestriction: {
        circle: {
          center: { latitude: property.latitude, longitude: property.longitude },
          radius: 2000.0
        }
      }
    }

    # Request one photo reference for every category except those flagged photo: false (stations).
    # places.photos returns a photo *resource name*, not the image — stored now, resolved to a media
    # URL at display time. rating already elevates the mask's billing tier, so photos rarely bumps it.
    field_mask = config[:photo] == false ? PLACES_FIELD_MASK : "#{PLACES_FIELD_MASK},places.photos"

    response = HTTParty.post(
      SEARCH_NEARBY_URL,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => places_key,
        "X-Goog-FieldMask" => field_mask
      },
      body: body.to_json
    )

    unless response.success?
      raise "searchNearby[#{category}] property #{property.id}: " \
            "HTTP #{response.code} — #{response.parsed_response.inspect[0, 300]}"
    end

    (response.parsed_response["places"] || []).each do |pl|
      lat = pl.dig("location", "latitude")
      lng = pl.dig("location", "longitude")
      Place.create!(
        property_id: property.id,
        category: category,
        place_id: pl["id"],
        name: pl.dig("displayName", "text"),
        latitude: lat,
        longitude: lng,
        rating: pl["rating"],
        photos: Array(pl.dig("photos", 0, "name")), # [] when none, else [first photo resource name]
        distance_meters: DistanceHelperV2New.haversine_meters(
          property.latitude, property.longitude, lat, lng
        )
      )
    end.count
  end

  def resolve_walking_minutes(property, station, routes_key)
    return nil if station.nil?

    unless routes_key.present?
      warn "  (skipping walking-time call for property #{property.id} — ROUTES_API not set)"
      return nil
    end

    fetch_walking_minutes(property, station, routes_key)
  end

  def fetch_walking_minutes(property, station, routes_key)
    body = {
      origin: { location: { latLng: { latitude: property.latitude, longitude: property.longitude } } },
      destination: { location: { latLng: { latitude: station.latitude, longitude: station.longitude } } },
      travelMode: "WALK"
    }

    response = HTTParty.post(
      COMPUTE_ROUTES_URL,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => routes_key,
        "X-Goog-FieldMask" => "routes.duration"
      },
      body: body.to_json
    )

    unless response.success?
      raise "computeRoutes property #{property.id}: " \
            "HTTP #{response.code} — #{response.parsed_response.inspect[0, 300]}"
    end

    duration_str = response.parsed_response.dig("routes", 0, "duration")
    return nil if duration_str.nil?

    sleep 0.15
    (duration_str.to_i / 60.0).round
  end

  # Builds the per-property score_inputs hash from the freshly inserted Place rows.
  # String keys match category strings and how jsonb round-trips.
  # Always iterates all 10 CATEGORIES_V2 so the stored shape has all keys even on
  # a single-category run (un-fetched categories produce nil values, which is expected).
  # peace_quiet_score is a derived scalar (no API) appended as one more key, computed
  # from the bar/restaurant/tourist_attraction densities just built.
  #
  # Example of a completed score_inputs (string keys, exactly as stored in the jsonb column):
  #
  #   {
  #     "convenience_store"  => { "nearest_m" => 120 },                 # proximity: nearest of category (metres)
  #     "supermarket"        => { "nearest_m" => 340 },
  #     "atm"                => { "nearest_m" => 70 },
  #     "cafe"               => { "tenth_m" => 480 },                   # density: distance to the 10th-nearest (metres)
  #     "restaurant"         => { "tenth_m" => 310 },
  #     "bar"                => { "tenth_m" => 620 },
  #     "park"               => { "nearest_m" => 200, "fifth_m" => 890 }, # hybrid: nearest + 5th-nearest (metres)
  #     "gym"                => { "nearest_m" => 550 },
  #     "tourist_attraction" => { "tenth_m" => 740 },
  #     "transit_station"    => { "time_to_station" => 7, "station_name" => "Meguro" }, # walk mins (Routes API) + name
  #     "peace_quiet_score"  => 0.62                                    # derived 0..1 (0 = lively, 1 = calm)
  #   }
  #
  # Any metric is nil when the data is missing (e.g. a category returned fewer than N results, or
  # time_to_station before ROUTES_API is set). The shape always has all 11 keys.
  def build_score_inputs_v2(property, walking_minutes = nil)
    result = CATEGORIES_V2.each_with_object({}) do |(category, config), acc|
      rows = property.places.where(category: category).order(:distance_meters)
      acc[category] = score_inputs_for(config[:score], rows, walking_minutes)
    end
    result["peace_quiet_score"] = PeaceQuietV2New.compute_peace_quiet_score(result)
    result
  end

  def score_inputs_for(score_type, rows, walking_minutes)
    case score_type
    when :proximity
      { "nearest_m" => rows.first&.distance_meters }
    when :density
      { "tenth_m" => (rows[9] || rows.last)&.distance_meters }
    when :park_hybrid
      { "nearest_m" => rows.first&.distance_meters,
        "fifth_m" => (rows[4] || rows.last)&.distance_meters }
    when :station
      # station_name comes free from the nearest-station Place row (displayName.text,
      # already fetched by the transit_station searchNearby call — no extra API call).
      { "time_to_station" => walking_minutes,
        "station_name" => rows.first&.name }
    end
  end
end
