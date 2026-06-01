namespace :places do
  desc "Import nearby places from Google"
  task import: :environment do
    properties = Property.all
    categories = [
      "restaurant",
      "cafe",
      "bar",
      "supermarket",
      "convenience_store",
      "gym",
      "park",
      "tourist_attraction"
    ]
    properties.each do |property|
      puts "Property:"
      puts property.name
      categories.each do |category|
        puts "------------------"
        puts "Category:"
        puts category

        response =
          HTTParty.get(
            "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
            query: {
              key: ENV.fetch("PLACES_API"),
              location: "#{property.latitude},#{property.longitude}",
              rankby: "distance",
              type: category
            }
          )

        results =
          response.parsed_response["results"]

        puts "Results returned:"
        puts results.count

        results.each do |place|
          place_id =
            place["place_id"]

          existing_place =
            Place.find_by(
              place_id: place_id
            )

          if existing_place
            puts "Skipping duplicate:"
            puts place["name"]
            next
          end

          photo_reference =
            place["photos"]
            &.first
            &.dig("photo_reference")

          Place.create!(
            place_id: place_id,
            name: place["name"],
            category: category,
            latitude:
              place["geometry"]["location"]["lat"],
            longitude:
              place["geometry"]["location"]["lng"],
            rating:
              place["rating"],
            photos:
              photo_reference ? [photo_reference] : []
          )

          puts "Created:"
          puts place["name"]
        end
      end
    end
  end
end
