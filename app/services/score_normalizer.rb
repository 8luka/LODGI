# Turns each listing's raw score_inputs (+ cached anchor travel times) into per-dimension
# values normalized to [0, 1] where higher is always better. Shared by the map (live re-rank)
# and the property show page (fit summary) so both score off the same basis.
#
# Returns { property_id => { dim => normalized_0_to_1 } }.
class ScoreNormalizer
  # Dimensions where a smaller raw value is better (closer/faster), so we invert after scaling.
  INVERT_DIMENSIONS = %i[station konbini supermarket atm cafe restaurant
                         bar park_nearest park_fifth gym tourist commute].freeze

  # In v2, commute and station are hard filters, not score terms — so they are NOT normalized.
  V2_SCORE_DIMENSIONS = %i[peace_quiet konbini supermarket atm cafe restaurant
                           bar park_nearest park_fifth gym tourist].freeze

  def self.call(listings, anchor_travel_times: {}, scoring_v2: false)
    new(listings, anchor_travel_times, scoring_v2).call
  end

  def initialize(listings, anchor_travel_times, scoring_v2)
    @listings = listings
    @anchor_travel_times = anchor_travel_times || {}
    @scoring_v2 = scoring_v2
  end

  def call
    raw = raw_dimensions
    raw = raw.slice(*V2_SCORE_DIMENSIONS) if @scoring_v2

    ranges = raw.transform_values do |values|
      clean = values.compact
      { min: clean.min, max: clean.max }
    end

    @listings.map do |listing|
      normalized = {}
      raw.each_key do |dim|
        normalized[dim] = normalize(listing, dim, ranges[dim])
      end
      [listing.id, normalized]
    end.to_h
  end

  private

  def raw_dimensions
    {
      peace_quiet: @listings.map { |l| l.score_inputs["peace_quiet_score"]&.to_f },
      station: @listings.map { |l| l.score_inputs.dig("transit_station", "time_to_station")&.to_f },
      konbini: @listings.map { |l| l.score_inputs.dig("convenience_store", "nearest_m")&.to_f },
      supermarket: @listings.map { |l| l.score_inputs.dig("supermarket", "nearest_m")&.to_f },
      atm: @listings.map { |l| l.score_inputs.dig("atm", "nearest_m")&.to_f },
      cafe: @listings.map { |l| l.score_inputs.dig("cafe", "tenth_m")&.to_f },
      restaurant: @listings.map { |l| l.score_inputs.dig("restaurant", "tenth_m")&.to_f },
      bar: @listings.map { |l| l.score_inputs.dig("bar", "tenth_m")&.to_f },
      park_nearest: @listings.map { |l| l.score_inputs.dig("park", "nearest_m")&.to_f },
      park_fifth: @listings.map { |l| l.score_inputs.dig("park", "fifth_m")&.to_f },
      gym: @listings.map { |l| l.score_inputs.dig("gym", "nearest_m")&.to_f },
      tourist: @listings.map { |l| l.score_inputs.dig("tourist_attraction", "tenth_m")&.to_f },
      commute: @anchor_travel_times.empty? ? nil : @listings.map { |l| @anchor_travel_times[l.id]&.to_f }
    }.compact
  end

  def raw_value(listing, dim)
    case dim
    when :peace_quiet   then listing.score_inputs["peace_quiet_score"]&.to_f
    when :station       then listing.score_inputs.dig("transit_station", "time_to_station")&.to_f
    when :konbini       then listing.score_inputs.dig("convenience_store", "nearest_m")&.to_f
    when :supermarket   then listing.score_inputs.dig("supermarket", "nearest_m")&.to_f
    when :atm           then listing.score_inputs.dig("atm", "nearest_m")&.to_f
    when :cafe          then listing.score_inputs.dig("cafe", "tenth_m")&.to_f
    when :restaurant    then listing.score_inputs.dig("restaurant", "tenth_m")&.to_f
    when :bar           then listing.score_inputs.dig("bar", "tenth_m")&.to_f
    when :park_nearest  then listing.score_inputs.dig("park", "nearest_m")&.to_f
    when :park_fifth    then listing.score_inputs.dig("park", "fifth_m")&.to_f
    when :gym           then listing.score_inputs.dig("gym", "nearest_m")&.to_f
    when :tourist       then listing.score_inputs.dig("tourist_attraction", "tenth_m")&.to_f
    when :commute       then @anchor_travel_times[listing.id]&.to_f
    end
  end

  def normalize(listing, dim, range)
    value = raw_value(listing, dim)
    min = range[:min]
    max = range[:max]
    span = (max - min).to_f if min && max

    n = if value.nil? || span.nil?
          0.0
        elsif span.zero?
          0.5
        else
          scaled = (value - min) / span
          INVERT_DIMENSIONS.include?(dim) ? 1.0 - scaled : scaled
        end

    n.round(4)
  end
end
