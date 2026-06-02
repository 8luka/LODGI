require Rails.root.join("lib/peace_quiet_v2_new")

namespace :places do
  desc <<~DESC
    Recompute derived score_inputs (peace_quiet_score) from already-stored data. No API calls.
    Args: [property_id] (optional — omit to recompute all properties).

    Use this to retune the peace_quiet thresholds (spec §7.3, the #1 tuning lever) cheaply:
    edit lib/peace_quiet_v2_new.rb, then run this task — no need to re-hit the Places API.
    After recomputing, run `rake places:generate_seed_v2` and commit the refreshed seed.
  DESC
  task :recompute_scores_v2, [:property_id] => :environment do |_t, args|
    scope = args[:property_id].present? ? Property.where(id: args[:property_id]) : Property.all

    updated = 0
    scope.find_each do |property|
      inputs = (property.score_inputs || {}).dup
      inputs["peace_quiet_score"] = PeaceQuietV2New.compute_peace_quiet_score(inputs)
      property.update!(score_inputs: inputs)
      updated += 1
      puts "Property #{property.id} (#{property.name}): peace_quiet_score = #{inputs['peace_quiet_score']}"
    end

    puts "Recomputed peace_quiet_score for #{updated} property(ies)."
  end
end
