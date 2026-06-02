require Rails.root.join("lib/distance_helper_v2_new")
require Rails.root.join("lib/peace_quiet_v2_new")

CATEGORIES_V2 = {
  "convenience_store" => { max: 5, score: :proximity },
  "supermarket" => { max: 5, score: :proximity },
  "atm" => { max: 5, score: :proximity },
  "cafe" => { max: 10, score: :density },
  "restaurant" => { max: 10, score: :density },
  "bar" => { max: 10, score: :density },
  "park" => { max: 5, score: :park_hybrid },
  "gym" => { max: 5, score: :proximity },
  "tourist_attraction" => { max: 10, score: :density },
  "transit_station" => { max: 1, score: :station }
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

    WARNING: This task creates new place rows on each run. Running it twice for the same property
    doubles its place rows. score_inputs will be computed from all current rows, which may give
    incorrect (over-saturated) density signals after a re-run. To get clean data, delete the
    property's places before re-running.

      # To re-import for a single property cleanly:
      # property.places.destroy_all
      # rake places:import_v2[property_id]
  DESC
  task :import_v2, [:property_id, :category] => :environment do |_t, args|
    places_key = ENV.fetch("PLACES_API_V2") do
      abort "PLACES_API_V2 is not set. Export your Google Places API (New) key first."
    end
    routes_key = ENV.fetch("ROUTES_API", nil)

    scope = args[:property_id].present? ? Property.where(id: args[:property_id]) : Property.all

    categories =
      if args[:category].present?
        filtered = CATEGORIES_V2.slice(args[:category])
        abort "Unknown category #{args[:category].inspect}. Valid: #{CATEGORIES_V2.keys.join(', ')}" if filtered.empty?
        filtered
      else
        CATEGORIES_V2
      end

    scope.find_each do |property|
      begin
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
    end
  end

  def fetch_and_persist_category(property, category, config, places_key)
    body = {
      includedTypes: [category],
      maxResultCount: config[:max],
      rankPreference: "DISTANCE",
      locationRestriction: {
        circle: {
          center: { latitude: property.latitude, longitude: property.longitude },
          radius: 2000.0
        }
      }
    }

    response = HTTParty.post(
      SEARCH_NEARBY_URL,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => places_key,
        "X-Goog-FieldMask" => PLACES_FIELD_MASK
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
