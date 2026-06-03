class Inquiry < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :property, optional: true
  belongs_to :anchor, polymorphic: true, optional: true

  # ── Priority slider defaults ────────────────────────────────────────────
  # Single source of truth for the three "Your priorities" sliders on /map.
  # Slider position == stored weight (both 0–3). Edit here to retune defaults.
  # commute_weight here is the *anchored* default — the weight a trip gets when
  # an anchor is set. Commute is meaningless without an anchor, so the controller
  # forces commute_weight to 0 (which also hides the Easy-commute slider) on any
  # anchorless inquiry. With an anchor: visiting 1, business/education 2.
  WEIGHT_DEFAULTS = {
    "visiting"  => { commute_weight: 1, quiet_weight: 1, station_weight: 1 },
    "business"  => { commute_weight: 2, quiet_weight: 1, station_weight: 1 },
    "education" => { commute_weight: 2, quiet_weight: 1, station_weight: 1 }
  }.freeze
  # Used when no trip type (why_visit) is selected.
  WEIGHT_FALLBACK = { commute_weight: 1, quiet_weight: 1, station_weight: 1 }.freeze

  def self.default_weights(why_visit)
    WEIGHT_DEFAULTS[why_visit.presence] || WEIGHT_FALLBACK
  end
end
