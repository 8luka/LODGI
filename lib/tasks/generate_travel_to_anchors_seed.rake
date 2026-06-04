namespace :travel_to_anchors do
  desc "Generate db/travel_to_anchors_seeds.rb from the database (cached anchor travel times). Does not call the API."
  task generate_seed: :environment do
    path = TravelToAnchorsSeedWriter.call
    puts "Wrote #{path}"
  end
end
