require Rails.root.join("lib/distance_helper_v2_new")

namespace :places do
  # Per-category fetch config (spec §2 / §9). The category string is the single
  # source of truth: it is the API includedTypes value, the places.category
  # value, AND the score_inputs key. No mapping layer.
  CATEGORIES_V2 = {
    "convenience_store"  => { max: 5,  score: :proximity },
    "supermarket"        => { max: 5,  score: :proximity },
    "atm"                => { max: 5,  score: :proximity },
    "cafe"               => { max: 10, score: :density },
    "restaurant"         => { max: 10, score: :density },
    "bar"                => { max: 10, score: :density },
    "park"               => { max: 5,  score: :park_hybrid }, # uses 1st + 5th
    "gym"                => { max: 5,  score: :proximity },
    "tourist_attraction" => { max: 10, score: :density }
  }.freeze

  SEARCH_NEARBY_URL = "https://places.googleapis.com/v1/places:searchNearby".freeze
  FIELD_MASK = "places.id,places.displayName,places.location,places.rating".freeze

  desc <<~DESC
    Import nearby places per property/category via the Places API (New). [property_id optional]

    WARNING: This task creates new place rows on each run. Running it twice for the
    same property doubles its place rows. score_inputs will be computed from all
    current rows, which may give incorrect (over-saturated) density signals after a
    re-run. To get clean data, delete the property's places before re-running.

      # To re-import for a single property cleanly:
      # property.places.destroy_all
      # rake places:import_v2[property_id]
  DESC
  task :import_v2, [:property_id] => :environment do |_t, args|
    api_key = ENV.fetch("PLACES_API") do
      abort "PLACES_API is not set. Export your Google Places API key first."
    end

    scope =
      if args[:property_id].present?
        Property.where(id: args[:property_id])
      else
        Property.all
      end

    scope.find_each do |property|
      begin
        fetched = 0

        ActiveRecord::Base.transaction do
          CATEGORIES_V2.each do |category, config|
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

            response =
              HTTParty.post(
                SEARCH_NEARBY_URL,
                headers: {
                  "Content-Type" => "application/json",
                  "X-Goog-Api-Key" => api_key,
                  "X-Goog-FieldMask" => FIELD_MASK
                },
                body: body.to_json
              )

            places = response.parsed_response["places"] || []

            places.each do |pl|
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
                distance_meters:
                  DistanceHelperV2New.haversine_meters(
                    property.latitude, property.longitude, lat, lng
                  )
              )
              fetched += 1
            end

            sleep 0.15 # rate limit, ~100-200ms between API calls
          end

          property.update!(score_inputs: build_score_inputs_v2(property))
        end

        puts "Property #{property.id} (#{property.name}): #{CATEGORIES_V2.size} categories, #{fetched} places fetched."
      rescue => e
        warn "!! Property #{property.id} (#{property.name}) FAILED: #{e.class}: #{e.message}"
        next
      end
    end
  end

  # Builds the per-property score_inputs hash (spec §6) from the freshly inserted
  # Place rows. String keys, to match the category strings and how jsonb round-trips.
  def build_score_inputs_v2(property)
    CATEGORIES_V2.each_with_object({}) do |(category, config), result|
      rows = property.places.where(category: category).order(:distance_meters)

      result[category] =
        case config[:score]
        when :proximity
          { "nearest_m" => rows.first&.distance_meters }
        when :density
          # 10th nearest; fall back to the last row if fewer than 10; nil if none.
          { "tenth_m" => (rows[9] || rows.last)&.distance_meters }
        when :park_hybrid
          # 1st nearest, plus 5th (fall back to last if fewer than 5; nil if none).
          {
            "nearest_m" => rows.first&.distance_meters,
            "fifth_m" => (rows[4] || rows.last)&.distance_meters
          }
        end
    end
  end
end
