puts "Seeding..."
# Destroy order must respect foreign keys: dependents before parents.
# places references properties (v2 property_id FK) and neighborhoods.
# property_amenities references properties.
# travel_to_anchors references properties (FK) and anchors (polymorphic) — clear it first so
# Property/Place/Neighborhood destroys don't hit the FK; the cached times are restored below.
TravelToAnchor.delete_all
CustomAnchor.destroy_all
Place.destroy_all
User.destroy_all
Property.destroy_all
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
load Rails.root.join("db/google_places_seeds_v2.rb")
# load Rails.root.join("db/google_places_seeds.rb") original place calls. Not needed but saved.

# Cached anchor travel times (rake travel_to_anchors:generate_seed). Optional: only present once
# generated, so guarded — a fresh checkout without the file just skips it.
travel_seed = Rails.root.join("db/travel_to_anchors_seeds.rb")
load travel_seed if File.exist?(travel_seed)

### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ###

# This is a property scraper that will get hashes of property info that must then be added to property_seeds
# Could automate this flow in the future.

# properties = ScrapePropertiesService.call([
# ])

# properties.each do |property_data|
#   neighborhood = Neighborhood.find_by(name: property_data.delete(:neighborhood))
#   Property.create!(property_data.merge(neighborhood: neighborhood))
# end
