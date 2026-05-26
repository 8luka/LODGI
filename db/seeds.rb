# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "Ending it all..."
User.destroy_all
Neighborhood.destroy_all
Property.destroy_all

user = User.new(
  email: "test@test.com",
  password: "111111"
)
user.save

### BASIC NEIGHBORHOOD SEEDS ### BASIC NEIGHBORHOOD SEEDS ### BASIC NEIGHBORHOOD SEEDS ### BASIC NEIGHBORHOOD SEEDS

neighborhood = Neighborhood.new(
  name: "Meguro",
  description: "A relaxed, upscale residential district that balances quiet tree-lined streets with a buzzing dining and café scene. The Meguro River serves as its scenic backbone, and the area has a distinctly local, unhurried character compared to its flashier neighbors.",
  features: "Meguro River walks, independent cafés, antique shops, Meguro Fudoson temple, family-friendly parks, low-key izakayas",
  ward: "Meguro-ku",
  latitude: "35.6340",
  longitude: "139.7153"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Naka-Meguro",
  description: "One of Tokyo's most coveted neighborhoods, Naka-Meguro hugs both banks of the Meguro River and is lined with independent boutiques, specialty coffee roasters, and intimate restaurants. It draws a creative, fashion-forward crowd and explodes with visitors every cherry blossom season.",
  features: "Cherry blossom-lined Meguro River, concept stores, specialty coffee, vinyl record shops, design studios, moody cocktail bars",
  ward: "Meguro-ku",
  latitude: "35.6438",
  longitude: "139.6993"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Ebisu",
  description: "Named after the famous brewery that once occupied its grounds, Ebisu is a polished, cosmopolitan neighborhood popular with expats and young professionals. It offers a sophisticated mix of famous restaurants, galleries, and shopping in a relatively calm, walkable setting.",
  features: "Yebisu Garden Place, Tokyo Metropolitan Museum of Photography, French bistros, craft beer bars, upscale supermarkets, wide pedestrian walkways",
  ward: "Shibuya-ku",
  latitude: "35.6467",
  longitude: "139.7100"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Shibuya",
  description: "One of Tokyo's most iconic and energetic districts, Shibuya is famous worldwide for its scramble crossing and serves as a major commercial and entertainment hub. Its streets pulse day and night with shoppers, commuters, tourists, and nightlife seekers.",
  features: "Shibuya Scramble Crossing, Shibuya 109, Center-gai, major department stores, live music venues, rooftop bars, Hachiko statue",
  ward: "Shibuya-ku",
  latitude: "35.6598",
  longitude: "139.7004"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Harajuku",
  description: "A neighborhood of delightful contradictions — serene Meiji Shrine sits minutes from the technicolor chaos of Takeshita Street. Harajuku is the birthplace of Tokyo street fashion subcultures and remains the city's most creative and youthful district.",
  features: "Takeshita Street, Meiji Shrine, Omotesando boulevard, vintage clothing stores, crepe stands, avant-garde fashion boutiques, Yoyogi Park",
  ward: "Shibuya-ku",
  latitude: "35.6702",
  longitude: "139.7027"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Shinjuku",
  description: "Tokyo's most multifaceted district — home to the world's busiest train station, towering skyscrapers, the sprawling Golden Gai bar alley, and the lively Kabukicho entertainment zone. Shinjuku never sleeps and caters to everyone from salarymen to tourists to night owls.",
  features: "Golden Gai, Kabukicho, Shinjuku Gyoen National Garden, Tokyo Metropolitan Government Building observation deck, department stores, memory lane (Omoide Yokocho)",
  ward: "Shinjuku-ku",
  latitude: "35.6938",
  longitude: "139.7034"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Roppongi",
  description: "An internationally minded district best known for its nightlife and world-class art institutions. By day, Roppongi is home to major embassies, sleek office towers, and three premier art museums; by night it transforms into one of Tokyo's most vibrant entertainment hubs.",
  features: "Mori Art Museum, National Art Center, 21_21 Design Sight, Roppongi Hills complex, international restaurants, rooftop city views, upscale nightclubs, gallery hopping",
  ward: "Minato-ku",
  latitude: "35.6628",
  longitude: "139.7314"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Jiyugaoka",
  description: "A charming, village-like neighborhood in southwest Tokyo that has earned a reputation as the city's 'sweets forest' capital. Its European-influenced streetscapes are lined with patisseries, French cafés, and stylish homeware boutiques, giving it a distinctly intimate and feminine aesthetic that sets it apart from the rest of the city.",
  features: "La Vita canal shopping district, patisseries and sweet shops, Jiyugaoka Sweets Forest, European-style architecture, independent homeware and interior stores, specialty tea houses, Kumano Shrine",
  ward: "Meguro-ku",
  latitude: "35.6076",
  longitude: "139.6682"
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Yotsuya",
  description: "A dignified, understated district where old Tokyo atmosphere lingers alongside government offices, prestigious schools, and Catholic institutions. Sitting between the Imperial Palace grounds and Shinjuku, Yotsuya has a contemplative, unhurried character — more a neighborhood for those who live and work in Tokyo than one that courts tourists.",
  features: "Yotsuya Station area, Sophia University, St. Ignatius Church, Shinjuku Gyoen proximity, historic moats and castle walls, quiet sake bars, traditional soba restaurants, Yotsuya Naito-machi greenery",
  ward: "Shinjuku-ku",
  latitude: "35.6863",
  longitude: "139.7298"
)
neighborhood.save

### BASIC PROPERTY SEEDS ### BASIC PROPERTY SEEDS ### BASIC PROPERTY SEEDS ### BASIC PROPERTY SEEDS

property = Property.new(
  name: "Hmlet Takadanobaba",
  neighborhood_id: 6,
  address: nil,
  price: "218,000",
  description: "9 minutes from Takadanobaba Station and 7 minutes from Zoshigaya Station, the property has a luxurious appearance and is located in a quiet residential area. In addition to having access to Shinjuku and Ikebukuro in 5 minutes and Otemachi in 13 minutes, it is just a 2-minute walk to the supermarket and drugstore. Convenience and livability are great features of this property with cafes, restaurants, gyms and other items you need for your daily life. The common space of the property has a veranda, so you can spend comfortable days in the pleasant sunlight.",
  agency: "Hmlet",
  rating: 4.8,
  layout: "7F",
  guests: "1",
  size: 25.92,
  rules: "
    This rental agreement will be a fixed-term contract, requiring you to vacate the property by the lease expiration date.

    Please note that an application screening process is required for all tenants. Upon receiving the estimate and moving forward with your application, you'll need to submit the following documents.
    1. A copy of your passport or a Japanese driver's license
    2. A copy of your visa or COE (Not required for visa-exempt or visa-free entries)
    3. A bank balance certificate for the payer (internet banking screenshots are acceptable) or employment verification document (e.g., employee ID, employment contract)

    ※If you have co-occupants, they must also provide documents 1 and 2.
    ※Japanese nationals are exempt from providing document 2.
    ※For contracts shorter than two months, full upfront payment is required, and only document 1 is necessary.

    Please be aware that early termination of the lease may incur a cancellation fee.

    If you wish to renew your lease beyond the expiration date, renewal in the same unit may not be possible if it is reserved for the next tenant. In such cases, we can offer alternative properties or units based on availability.

    Smoking is prohibited on all premises, including balconies, and applies to electronic cigarettes as well.

    For tenants with pets, a pet deposit of ¥110,000 will be added to the initial fees, in addition to the monthly rent.

    All rooms are furnished, and removal of the furniture is not permitted.

    While we conduct regular cleaning of common areas, room cleaning services are not included in the rent. If desired, we can connect you with our partner cleaning company.
  ",
  property_type: "Studio Appartment",
  available_from: "May 31, 2026",
  available_until: nil,
  latitude: "35.71531444604038",
  longitude: "139.7112255609536"
)
property.save

property = Property.new(
  name: "QuinTet Ebisu",
  neighborhood_id: 3,
  address: nil,
  price: "447,119",
  description: "Feel at home wherever you choose to live with Blueground. You’ll love this lovely Higashi furnished one bedroom apartment with its modern decor, fully equipped kitchen, and spacious living room. Ideally located, you’re close to all the best that Tokyo has to offer!",
  agency: "Blueground",
  rating: 4.8,
  layout: "1 Bedroom, 1 Bath, 1 WC",
  guests: "2",
  size: 45,
  rules: "
    After booking, if you request to cancel 15 or more days before move-in, there’s a half month’s rent charge. If you request to cancel fewer than 15 days before, there’s one month’s rent charge. No service/booking or card processing fee refunds.
    Move in from 4pm to 11pm / Move out by 11am
    No smoking allowed
    No parties or events allowed
    No pets allowed
    ",
  property_type: "Appartment",
  available_from: "July 5, 2026",
  available_until: nil,
  latitude: "35.64897783169701",
  longitude: "139.71006471315619"
)
property.save

property = Property.new(
  name: "Third Property",
  neighborhood_id: 3,
  address: nil,
  price: "447,119",
  description: "Feel at home wherever you choose to live with Blueground. You’ll love this lovely Higashi furnished one bedroom apartment with its modern decor, fully equipped kitchen, and spacious living room. Ideally located, you’re close to all the best that Tokyo has to offer!",
  agency: "Blueground",
  rating: 4.8,
  layout: "1 Bedroom, 1 Bath, 1 WC",
  guests: "2",
  size: 45,
  rules: "
    After booking, if you request to cancel 15 or more days before move-in, there’s a half month’s rent charge. If you request to cancel fewer than 15 days before, there’s one month’s rent charge. No service/booking or card processing fee refunds.
    Move in from 4pm to 11pm / Move out by 11am
    No smoking allowed
    No parties or events allowed
    No pets allowed
    ",
  property_type: "Appartment",
  available_from: "July 5, 2026",
  available_until: nil,
  latitude: "35.62637820323294",
  longitude: "139.70832314920878"
)
property.save

### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS

amenity = Amenity.new(
  name: "Bike Parking",
  specs: "mingcute:bike-fill",
)
amenity.save
amenity = Amenity.new(
  name: "Hair Dryer",
  specs: "mdi:hair-dryer",
)
amenity.save
amenity = Amenity.new(
  name: "Kettle",
  specs: "material-symbols:kettle",
)
amenity.save
amenity = Amenity.new(
  name: "Iron",
  icon: "material-symbols:iron",
)
amenity.save
amenity = Amenity.new(
  name: "Microwave",
  icon: "material-symbols:microwave",
)
amenity.save
amenity = Amenity.new(
  name: "Washing Machine",
  icon: "boxicons:washer-filled",
)
amenity.save
amenity = Amenity.new(
  name: "Shower Dryer",
  icon: "material-symbols:iron",
)
amenity.save
amenity = Amenity.new(
  name: "Stovetop",
  icon: "fluent:stove-16-regular",
)
amenity.save
amenity = Amenity.new(
  name: "Utilities Included",
  icon: "pinhead:utility-shutoff-with-bolt",
)
amenity.save
amenity = Amenity.new(
  name: "Air Conditioning",
  icon: "icon-park-outline:air-conditioning",
)
amenity.save
amenity = Amenity.new(
  name: "Bedding",
  icon: "boxicons:blanket-filled",
)
amenity.save
amenity = Amenity.new(
  name: "Towels",
  icon: "lucide-lab:towel-folded",
)
amenity.save
amenity = Amenity.new(
  name: "English Support",
  icon: "icon-park-solid:english",
)
amenity.save

property = Property.new(
  name: Faker::Locations::Australia.animal,
  address: Faker::Address.street_address,
  description: Faker::String.random(length: 90..138),
  phone_number: Faker::PhoneNumber.phone_number,
  price_per_night: Faker::Number.between(from: 40, to: 200),
  capacity: Faker::Number.between(from: 1, to: 12),
  amenities: Flat::AMENITIES.sample,
)



puts "Creating flats..."
30.times do
  property = Property.new(
    # interior: Faker::LoremFlickr.image(size: "300x300", search_terms: [ 'appartment', 'interior' ]),
    name: Faker::Locations::Australia.animal,
    address: Faker::Address.street_address,
    description: Faker::String.random(length: 90..138),
    price: Faker::PhoneNumber.phone_number,
    price_per_night: Faker::Number.between(from: 40, to: 200),
    capacity: Faker::Number.between(from: 1, to: 12),
    amenities: Flat::AMENITIES.sample,
  )

  url = Faker::LoremFlickr.image(size: "300x300", search_terms: [ 'apartment', 'interior' ])
  file = URI.open(url)
  flat.interior.attach(io: file, filename: File.basename(URI.parse(url).path), content_type: "image/jpeg")

  flat.save
end
