# For organization, property and amenity seeds are now in their own files
# Later in this file they are loaded and seed when seeds.rb is ran

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
  name: "Meguro",
  description: "A relaxed, upscale residential district that balances quiet tree-lined streets with a buzzing dining and café scene. The Meguro River serves as its scenic backbone, and the area has a distinctly local, unhurried character compared to its flashier neighbors.",
  features: "Meguro River walks, independent cafés, antique shops, Meguro Fudoson temple, family-friendly parks, low-key izakayas",
  ward: "Meguro-ku",
  latitude: "35.6340",
  longitude: "139.7153",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Shinagawa",
  description: "One of Tokyo's oldest post towns along the historic Tokaido highway, Shinagawa has reinvented itself as a sleek transit hub and business district while retaining pockets of old-town charm. Its waterfront location along Tokyo Bay gives it a spacious, open feel rarely found this close to the city center.",
  features: "Shinagawa Aquarium, Tennozu Isle art district, Togoshi Ginza shopping street, waterfront promenades, business hotel clusters, historic Tokaido shukuba townscape",
  ward: "Shinagawa-ku",
  latitude: "35.6284",
  longitude: "139.7387",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Gotanda",
  description: "A hardworking, unpretentious district that sits at the crossroads of Tokyo's everyday city life. Gotanda hums with salaryman izakayas, ramen shops, and karaoke bars by night, while its riverside areas and quiet backstreets offer a more relaxed side. It lacks the polish of its neighbors but makes up for it with genuine, unfiltered Tokyo energy.",
  features: "Meguro River riverside walks, dense izakaya alleys, Gotanda Film Center, budget-friendly ramen and yakiniku, lively nightlife strips, easy Yamanote Line access",
  ward: "Shinagawa-ku",
  latitude: "35.6263",
  longitude: "139.7237",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Ebisu",
  description: "Named after the famous brewery that once occupied its grounds, Ebisu is a polished, cosmopolitan neighborhood popular with expats and young professionals. It offers a sophisticated mix of famous restaurants, galleries, and shopping in a relatively calm, walkable setting.",
  features: "Yebisu Garden Place, Tokyo Metropolitan Museum of Photography, French bistros, craft beer bars, upscale supermarkets, wide pedestrian walkways",
  ward: "Shibuya-ku",
  latitude: "35.6467",
  longitude: "139.7100",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Shibuya",
  description: "One of Tokyo's most iconic and energetic districts, Shibuya is famous worldwide for its scramble crossing and serves as a major commercial and entertainment hub. Its streets pulse day and night with shoppers, commuters, tourists, and nightlife seekers.",
  features: "Shibuya Scramble Crossing, Shibuya 109, Center-gai, major department stores, live music venues, rooftop bars, Hachiko statue",
  ward: "Shibuya-ku",
  latitude: "35.6598",
  longitude: "139.7004",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Harajuku",
  description: "A neighborhood of delightful contradictions — serene Meiji Shrine sits minutes from the technicolor chaos of Takeshita Street. Harajuku is the birthplace of Tokyo street fashion subcultures and remains the city's most creative and youthful district.",
  features: "Takeshita Street, Meiji Shrine, Omotesando boulevard, vintage clothing stores, crepe stands, avant-garde fashion boutiques, Yoyogi Park",
  ward: "Shibuya-ku",
  latitude: "35.6702",
  longitude: "139.7027",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Shinjuku",
  description: "Tokyo's most multifaceted district — home to the world's busiest train station, towering skyscrapers, the sprawling Golden Gai bar alley, and the lively Kabukicho entertainment zone. Shinjuku never sleeps and caters to everyone from salarymen to tourists to night owls.",
  features: "Golden Gai, Kabukicho, Shinjuku Gyoen National Garden, Tokyo Metropolitan Government Building observation deck, department stores, memory lane (Omoide Yokocho)",
  ward: "Shinjuku-ku",
  latitude: "35.6938",
  longitude: "139.7034",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Roppongi",
  description: "A district best known for its nightlife and world-class art institutions. By day, Roppongi is home to major embassies, sleek office towers, and three premier art museums; by night it transforms into one of Tokyo's most vibrant entertainment hubs.",
  features: "Mori Art Museum, National Art Center, 21_21 Design Sight, Roppongi Hills complex, international restaurants, rooftop city views, upscale nightclubs, gallery hopping",
  ward: "Minato-ku",
  latitude: "35.6628",
  longitude: "139.7314",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Jiyugaoka",
  description: "A charming, village-like neighborhood in southwest Tokyo that has earned a reputation as the city's 'sweets forest' capital. Its European-influenced streetscapes are lined with patisseries, French cafés, and stylish homeware boutiques, giving it a distinctly intimate and feminine aesthetic that sets it apart from the rest of the city.",
  features: "La Vita canal shopping district, patisseries and sweet shops, Jiyugaoka Sweets Forest, European-style architecture, independent homeware and interior stores, specialty tea houses, Kumano Shrine",
  ward: "Meguro-ku",
  latitude: "35.6076",
  longitude: "139.6682",
  photos: []
)
neighborhood.save

neighborhood = Neighborhood.new(
  name: "Yotsuya",
  description: "A dignified, understated district where old Tokyo atmosphere lingers alongside government offices, prestigious schools, and Catholic institutions. Sitting between the Imperial Palace grounds and Shinjuku, Yotsuya has a contemplative, unhurried character — more a neighborhood for those who live and work in Tokyo than one that courts tourists.",
  features: "Yotsuya Station area, Sophia University, St. Ignatius Church, Shinjuku Gyoen proximity, historic moats and castle walls, quiet sake bars, traditional soba restaurants, Yotsuya Naito-machi greenery",
  ward: "Shinjuku-ku",
  latitude: "35.6863",
  longitude: "139.7298",
  photos: []
)
neighborhood.save

# Seeding properties and amenities from a different file

load Rails.root.join("db/property_seeds.rb")
load Rails.root.join("db/amenity_seeds.rb")

### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ### DO NOT DELETE THE BELOW !!! ###

# This is a property scraper that will get hashes of property info that must then be added to property_seeds
# Could automate this flow in the future.

# properties = ScrapePropertiesService.call([
# ])

# properties.each do |property_data|
#   neighborhood = Neighborhood.find_by(name: property_data.delete(:neighborhood))
#   Property.create!(property_data.merge(neighborhood: neighborhood))
# end

#scraper history
# "https://e-housing.jp/short-term/dash-living/tokyo/meguro/estlargo-meguro-studio/302?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924",
# "https://e-housing.jp/short-term/e-housing-exclusive/tokyo/meguro/nakameguro-claire-higashiyama/604?wards=4&wname=Meguro+Ward&location_point=139.6370344470951%2C35.60107634539&location_point=139.6370344470951%2C35.6759139893914&location_point=139.7764485489898%2C35.6759139893914&location_point=139.7764485489898%2C35.60107634539",
# "https://e-housing.jp/short-term/blueground-japan/tokyo/meguro/tyo-180-blueground-japan-the-parkhabio-meguro-place/2?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924",
# "https://e-housing.jp/short-term/hmlet-japan/tokyo/shibuya/hmlet-nishi-shinjuku/405?search=Shibuya&location_point=139.70210363698453%2C35.65484912628266&location_point=139.70210363698453%2C35.65787886624186&location_point=139.7077489630155%2C35.65787886624186&location_point=139.7077489630155%2C35.65484912628266",
# "https://e-housing.jp/short-term/sumyca/tokyo/meguro/stylish-designers-with-furniture-and-appliances-palace-studio-shibuya-west/207?search=Shibuya&location_point=139.6820930092275%2C35.61706184412018&location_point=139.6820930092275%2C35.647084981494615&location_point=139.72696889342538%2C35.647084981494615&location_point=139.72696889342538%2C35.61706184412018",
# "https://e-housing.jp/short-term/the-apartment-hotel/tokyo/shibuya/the-apartment-hotel-ebisu-1/102?location_point=139.66323872820473%2C35.62997130800836&location_point=139.66323872820473%2C35.67854464511375&location_point=139.75374323156873%2C35.67854464511375&location_point=139.75374323156873%2C35.62997130800836",
# "https://e-housing.jp/short-term/hmlet-japan/tokyo/meguro/hmlet-shibuyaohashi/203?location_point=139.66323872820473%2C35.62997130800836&location_point=139.66323872820473%2C35.67854464511375&location_point=139.75374323156873%2C35.67854464511375&location_point=139.75374323156873%2C35.62997130800836",
# "https://e-housing.jp/short-term/the-apartment-hotel/tokyo/shibuya/the-apartment-hotel-shibuya-1/701?location_point=139.66323872820473%2C35.62997130800836&location_point=139.66323872820473%2C35.67854464511375&location_point=139.75374323156873%2C35.67854464511375&location_point=139.75374323156873%2C35.62997130800836",
# "https://e-housing.jp/short-term/blueground-japan/tokyo/meguro/the-parkhabio-shibuya-cross-1004-tyo8/2?location_point=139.66323872820473%2C35.62997130800836&location_point=139.66323872820473%2C35.67854464511375&location_point=139.75374323156873%2C35.67854464511375&location_point=139.75374323156873%2C35.62997130800836",
# "https://e-housing.jp/short-term/sumyca/tokyo/shibuya/t-s-heim/201?location_point=139.70456453898925%2C35.6401014390662&location_point=139.70456453898925%2C35.65541426923116&location_point=139.72745727198006%2C35.65541426923116&location_point=139.72745727198006%2C35.6401014390662",
# "https://e-housing.jp/short-term/sumyca/tokyo/shibuya/oakrest-ebisu-503/503?location_point=139.70456453898925%2C35.6401014390662&location_point=139.70456453898925%2C35.65541426923116&location_point=139.72745727198006%2C35.65541426923116&location_point=139.72745727198006%2C35.6401014390662"
# "https://e-housing.jp/short-term/dash-living/tokyo/meguro/estlargo-meguro-studio/302?bed_rooms=0%2C1&bed_rooms_temp=0%2C1&features=268&price_from=0&price_to=828600&location_point=139.7010341580218%2C35.628422174175924&location_point=139.7010341580218%2C35.63772205341006&location_point=139.7161346919545%2C35.63772205341006&location_point=139.7161346919545%2C35.628422174175924"
# "https://e-housing.jp/short-term/blueground-japan/tokyo/meguro/tyo-150-blueground-japan-prime-urban-meguro-riverfront/301?location_point=139.6863157306276%2C35.625503939922126&location_point=139.6863157306276%2C35.654956199471286&location_point=139.73034281098347%2C35.654956199471286&location_point=139.73034281098347%2C35.625503939922126",
# "https://e-housing.jp/short-term/-22/tokyo/meguro/mynavi-stay-ebisu-square/110?location_point=139.6863157306276%2C35.625503939922126&location_point=139.6863157306276%2C35.654956199471286&location_point=139.73034281098347%2C35.654956199471286&location_point=139.73034281098347%2C35.625503939922126",
# "https://e-housing.jp/short-term/sumyca/tokyo/shibuya/initial-fee-free-campaign-is-underway-1/202?location_point=139.6863157306276%2C35.625503939922126&location_point=139.6863157306276%2C35.654956199471286&location_point=139.73034281098347%2C35.654956199471286&location_point=139.73034281098347%2C35.625503939922126",
# "https://e-housing.jp/short-term/hmlet-japan/tokyo/meguro/hmlet-yutenji/202?location_point=139.6821082009575%2C35.62184629709685&location_point=139.6821082009575%2C35.6512999044055&location_point=139.72613528131336%2C35.6512999044055&location_point=139.72613528131336%2C35.62184629709685",
# "https://e-housing.jp/short-term/sumii-apartments/tokyo/shinagawa/sumii-nishi-gotanda/Apt?location_point=139.69394605535405%2C35.6183377935895&location_point=139.69394605535405%2C35.6477926935904&location_point=139.73797313570995%2C35.6477926935904&location_point=139.73797313570995%2C35.6183377935895",
# "https://e-housing.jp/short-term/sumyca/tokyo/minato/pl-park-lane-shirokane-takanawa-202/202?location_point=139.69394605535405%2C35.6183377935895&location_point=139.69394605535405%2C35.6477926935904&location_point=139.73797313570995%2C35.6477926935904&location_point=139.73797313570995%2C35.6183377935895",
# "https://e-housing.jp/short-term/hmlet-japan/tokyo/shinagawa/hmlet-higashi-gotanda/1201?location_point=139.72477012115692%2C35.62632737303414&location_point=139.72477012115692%2C35.62649606494882&location_point=139.72502224878934%2C35.62649606494882&location_point=139.72502224878934%2C35.62632737303414",
# "https://e-housing.jp/short-term/-22/tokyo/shinagawa/mynavi-stay-nishi-gotanda2/412?location_point=139.71941974097808%2C35.628501543294284&location_point=139.71941974097808%2C35.628670230621566&location_point=139.71967186861048%2C35.628670230621566&location_point=139.71967186861048%2C35.628501543294284"
# "https://e-housing.jp/short-term/sumii-apartments/tokyo/meguro/sumii-meguro/Apt?location_point=139.6957753915168%2C35.62904210210972&location_point=139.6957753915168%2C35.642964564499415&location_point=139.71658645834265%2C35.642964564499415&location_point=139.71658645834265%2C35.62904210210972",
# "https://e-housing.jp/short-term/sumii-apartments/tokyo/shinagawa/sumii-nishi-gotanda/Apt?location_point=139.71240510098878%2C35.61580840335309&location_point=139.71240510098878%2C35.62973317043899&location_point=139.73321616781456%2C35.62973317043899&location_point=139.73321616781456%2C35.61580840335309",
# "https://e-housing.jp/short-term/sumyca/tokyo/shinagawa/maison-miyashita-2nd-and-3rd-floor/2F,%203F?location_point=139.71212404228365%2C35.6161615140853&location_point=139.71212404228365%2C35.630086219685346&location_point=139.7329351091095%2C35.630086219685346&location_point=139.7329351091095%2C35.6161615140853",
# "https://e-housing.jp/short-term/blueground-japan/tokyo/shinagawa/tyo-135-blueground-japan-la-sante-ikedayama/1202?location_point=139.7220921861838%2C35.6280308783207&location_point=139.7220921861838%2C35.62819956664106&location_point=139.72234431381622%2C35.62819956664106&location_point=139.72234431381622%2C35.6280308783207",
# "https://e-housing.jp/short-term/dash-living/tokyo/shinagawa/dash-living-osaki-1-bedroom-with-study/303?location_point=139.7229038124197%2C35.61699524254424&location_point=139.7229038124197%2C35.61716395414669&location_point=139.72315594005215%2C35.61716395414669&location_point=139.72315594005215%2C35.61699524254424",
# "https://e-housing.jp/short-term/e-housing-exclusive/tokyo/shibuya/shibuya-shoto/702?location_point=139.68383402966396%2C35.65089691925417&location_point=139.68383402966396%2C35.670393500597164&location_point=139.71298618838665%2C35.670393500597164&location_point=139.71298618838665%2C35.65089691925417",
# "https://e-housing.jp/short-term/blueground-japan/tokyo/meguro/the-parkhabio-shibuya-cross-1103-tyo9/3?location_point=139.68426106006035%2C35.6452439736908&location_point=139.68426106006035%2C35.66474193500167&location_point=139.71341321878305%2C35.66474193500167&location_point=139.71341321878305%2C35.6452439736908",
# "https://e-housing.jp/short-term/sumyca/tokyo/shibuya/newly-built-condominium-10-min-walk-from-shibuya-station-bathroom-dryer-include/301?location_point=139.70245373135762%2C35.66122675365916&location_point=139.70245373135762%2C35.66289285506918&location_point=139.70494500466864%2C35.66289285506918&location_point=139.70494500466864%2C35.66122675365916"
