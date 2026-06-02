# Computes peace_quiet_score (0 = lively, 1 = calm) from a property's already-fetched
# score_inputs. Pure function of bar/restaurant/tourist_attraction density (tenth_m) —
# needs no API call, so it is computed at import time and re-computable for tuning via
# `rake places:recompute_scores_v2`. Thresholds here are the #1 tuning lever (spec §7.3).
#
# Kept separate with the _v2_new suffix to stay distinct from anything pre-existing.
module PeaceQuietV2New
  module_function

  # score_inputs is the per-property hash with string keys (as built in import and as
  # round-tripped from the jsonb column). Returns a Float in [0, 1] rounded to 3 dp.
  def compute_peace_quiet_score(score_inputs)
    bar_lively        = proximity_curve(tenth(score_inputs, "bar"),                lively_close: 80,  calm_far: 800)
    restaurant_lively = proximity_curve(tenth(score_inputs, "restaurant"),         lively_close: 60,  calm_far: 600)
    tourist_lively    = proximity_curve(tenth(score_inputs, "tourist_attraction"), lively_close: 200, calm_far: 1500)

    liveliness = (0.4 * bar_lively) + (0.3 * restaurant_lively) + (0.3 * tourist_lively)
    (1.0 - liveliness).round(3) # 0 = lively, 1 = calm
  end

  # Closer than lively_close → fully lively (1.0); farther than calm_far → fully calm (0.0);
  # linear between. Neutral 0.5 when the underlying density is missing (sparse/zero results).
  def proximity_curve(distance, lively_close:, calm_far:)
    return 0.5 if distance.nil?
    return 1.0 if distance <= lively_close
    return 0.0 if distance >= calm_far

    1.0 - ((distance - lively_close).to_f / (calm_far - lively_close))
  end

  def tenth(score_inputs, category)
    score_inputs.dig(category, "tenth_m")
  end
end
