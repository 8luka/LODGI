namespace :travel_to_anchors do
  desc "Generate db/travel_to_anchors_seeds.rb from the database (cached anchor travel times). Does not call the API."
  task generate_seed: :environment do
    path = TravelToAnchorsSeedWriter.call
    puts "Wrote #{path}"
  end

  desc "Compute travel times for all anchors using haversine walking formula (no API) and write db/travel_to_anchors_seeds.rb. Requires USE_LOCAL_FORMULA = true in AnchorTravelTimesService."
  task generate_seed_local: :environment do
    anchors = Neighborhood.all.to_a + Place.all.to_a + CustomAnchor.all.to_a
    puts "Computing haversine walk times for #{anchors.size} anchors..."
    anchors.each { |anchor| AnchorTravelTimesService.call(anchor) }
    puts "Done. Wrote db/travel_to_anchors_seeds.rb"
  end
end
