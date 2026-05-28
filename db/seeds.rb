puts "Seeding..."
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
  name: "Meguro City",
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
  name: "Shibuya City",
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
  description: "A district best known for its nightlife and world-class art institutions. By day, Roppongi is home to major embassies, sleek office towers, and three premier art museums; by night it transforms into one of Tokyo's most vibrant entertainment hubs.",
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

### PROPERTY SEEDS ### PROPERTY SEEDS ### PROPERTY SEEDS ### PROPERTY SEEDS ### PROPERTY SEEDS ### PROPERTY SEEDS ###

properties = ScrapePropertiesService.call([
  "https://e-housing.jp/short-term/dash-living/tokyo/meguro/estlargo-meguro-studio/302?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924",
])

# properties = ScrapePropertiesService.call([
#   "https://e-housing.jp/short-term/dash-living/tokyo/meguro/estlargo-meguro-studio/302?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924",
#   "https://e-housing.jp/short-term/e-housing-exclusive/tokyo/meguro/nakameguro-claire-higashiyama/604?wards=4&wname=Meguro+Ward&location_point=139.6370344470951%2C35.60107634539&location_point=139.6370344470951%2C35.6759139893914&location_point=139.7764485489898%2C35.6759139893914&location_point=139.7764485489898%2C35.60107634539",
#   "https://e-housing.jp/short-term/blueground-japan/tokyo/meguro/tyo-180-blueground-japan-the-parkhabio-meguro-place/2?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924",
#   "https://e-housing.jp/short-term/hmlet-japan/tokyo/shibuya/hmlet-nishi-shinjuku/405?search=Shibuya&location_point=139.70210363698453%2C35.65484912628266&location_point=139.70210363698453%2C35.65787886624186&location_point=139.7077489630155%2C35.65787886624186&location_point=139.7077489630155%2C35.65484912628266"
# ])

properties.each do |property_data|
  neighborhood = Neighborhood.find_by(name: property_data.delete(:neighborhood))
  Property.create!(property_data.merge(neighborhood: neighborhood))
end

### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS ### BASIC AMENITY SEEDS

amenity = Amenity.new(
  name: "Bike Parking",
  icon: "mingcute:bike-fill",
)
amenity.save
amenity = Amenity.new(
  name: "Hair Dryer",
  icon: "mdi:hair-dryer",
)
amenity.save
amenity = Amenity.new(
  name: "Kettle",
  icon: "material-symbols:kettle",
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
