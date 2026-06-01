namespace :places do
  desc "Generate places seed file"

  task generate_seed: :environment do
    seed_path =
      Rails.root.join(
        "db/google_places_seeds.rb"
      )

    File.open(seed_path, "w") do |file|
      file.puts "places = ["

      Place.find_each do |place|
        file.puts <<~RUBY
          {
            place_id: #{place.place_id.inspect},
            name: #{place.name.inspect},
            category: #{place.category.inspect},
            latitude: #{place.latitude},
            longitude: #{place.longitude},
            rating: #{place.rating.inspect},
            photos: #{place.photos.inspect}
          },
        RUBY
      end

      file.puts "]"

      file.puts <<~RUBY

        places.each do |place|

          Place.find_or_create_by!(
            place_id: place[:place_id]
          ) do |p|

            p.name = place[:name]
            p.category = place[:category]
            p.latitude = place[:latitude]
            p.longitude = place[:longitude]
            p.rating = place[:rating]
            p.photos = place[:photos]

          end

        end
      RUBY
    end

    puts "Generated:"
    puts seed_path
  end
end
