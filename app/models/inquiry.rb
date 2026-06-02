class Inquiry < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :property, optional: true
  belongs_to :anchor, polymorphic: true, optional: true

  # ── Priority slider defaults ────────────────────────────────────────────
  # Single source of truth for the three "Your priorities" sliders on /map.
  # Slider position == stored weight (both 0–3). Edit here to retune defaults.
  # commute_weight 0 also means: hide the Easy-commute slider. Note the
  # controller forces commute_weight to 0 on any anchorless inquiry (no anchor =
  # nothing to commute to), so these business/education defaults of 2 only take
  # effect once an anchor is set.
  WEIGHT_DEFAULTS = {
    "visiting"  => { commute_weight: 0, quiet_weight: 1, station_weight: 1 },
    "business"  => { commute_weight: 2, quiet_weight: 1, station_weight: 1 },
    "education" => { commute_weight: 2, quiet_weight: 1, station_weight: 1 }
  }.freeze
  # Used when no trip type (why_visit) is selected.
  WEIGHT_FALLBACK = { commute_weight: 1, quiet_weight: 1, station_weight: 1 }.freeze

  def self.default_weights(why_visit)
    WEIGHT_DEFAULTS[why_visit.presence] || WEIGHT_FALLBACK
  end
end
