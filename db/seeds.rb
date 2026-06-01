puts "Seeding..."
User.destroy_all
Property.destroy_all
Place.destroy_all
Neighborhood.destroy_all

user = User.new(
  email: "test@test.com",
  password: "111111"
)
user.save

load Rails.root.join("db/neighborhood_seeds.rb")
load Rails.root.join("db/property_seeds.rb")
load Rails.root.join("db/amenity_seeds.rb")
load Rails.root.join("db/place_seeds.rb")

### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ###

# This is a property scraper that will get hashes of property info that must then be added to property_seeds
# Could automate this flow in the future.

# properties = ScrapePropertiesService.call([
# ])

# properties.each do |property_data|
#   neighborhood = Neighborhood.find_by(name: property_data.delete(:neighborhood))
#   Property.create!(property_data.merge(neighborhood: neighborhood))
# end
