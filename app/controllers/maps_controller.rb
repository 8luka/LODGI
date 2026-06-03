class MapsController < ApplicationController
  # Single switch between the old multi-slider scoring and the simplified v2 system
  # (simplified_scoring_spec.md). Flip to false to fall back to the original panel + engine.
  SCORING_V2 = false

  # Default commute filter bucket (minutes) by trip type; nil = "Any". Commute-heavy trips
  # pre-narrow to 30 min, leisure trips show everything until the user opts in.
  COMMUTE_BUCKET_DEFAULTS = { "business" => 30, "education" => 30 }.freeze

  def map
    # Ordered by price as the stable placeholder ranking until the fit-score
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    @anchor = nil
    travel_times = {}
    if inquiry&.anchor.present?
      @anchor = {
        id: inquiry.anchor.id,
        name: inquiry.anchor.name,
        latitude: inquiry.anchor.latitude,
        longitude: inquiry.anchor.longitude
      }
      # Cached transit times for this anchor (filled by AnchorTravelTimesJob on inquiry submit).
      # Read-only here; nil for any property not yet cached. Scoring's commute term handles nil.
      travel_times = TravelToAnchor.where(anchor: inquiry.anchor).pluck(:property_id, :travel_time).to_h
    end
    @properties_records = Property.includes(:neighborhood).order(:price)
    # Max-price hard filter ceiling, derived from the priciest listing (rounded up to the
    # slider's 10,000 step) so no listing is ever unreachable. Falls back to 500,000 when empty.
    ceiling = @properties_records.maximum(:price).to_f
    @max_price = ceiling.positive? ? (ceiling / 10_000).ceil * 10_000 : 500_000
    @scoring_v2 = SCORING_V2
    @commute_bucket_default = COMMUTE_BUCKET_DEFAULTS[@trip_type] if @scoring_v2
    @normalized_inputs = ScoreNormalizer.call(@properties_records,
                                              anchor_travel_times: travel_times, scoring_v2: SCORING_V2)
    # Nearest POI of each category per property, for the popup's toggle rows. Derived from the
    # already-persisted Place.distance_meters (no API call) — one grouped MIN over all listings.
    nearest_poi = nearest_poi_by_property(@properties_records)
    @properties = JSON.generate(
      @properties_records.map { |property| property_payload(property, travel_times, nearest_poi[property.id] || {}) }
    )
    @neighborhoods = Neighborhood.all
  end

  private

  # One property's data for the map JS: map/filter fields plus the scoring inputs
  # (score_inputs jsonb + cached travel time to the anchor, nil when uncached/no anchor)
  # and nearest_poi_m { category => metres } for the popup's amenity rows.
  def property_payload(property, travel_times, nearest_poi = {})
    {
      id: property.id,
      name: property.name,
      latitude: property.latitude,
      longitude: property.longitude,
      layout: property.layout,
      price: property.price,
      stations: property.stations,
      images: property.images,
      neighborhood_name: property.neighborhood.name,
      availability: property.availability,
      score_inputs: property.score_inputs,
      travel_time_to_anchor: travel_times[property.id],
      nearest_poi_m: nearest_poi
    }
  end

  # { property_id => { category => nearest_distance_metres } } for all listings, from the
  # cached Place rows. The popup turns these into walk-minute amenity rows for active toggles.
  def nearest_poi_by_property(listings)
    rows = Place.where(property_id: listings.map(&:id))
                .where.not(distance_meters: nil)
                .group(:property_id, :category)
                .minimum(:distance_meters)
    rows.each_with_object(Hash.new { |h, k| h[k] = {} }) do |((property_id, category), metres), acc|
      acc[property_id][category] = metres
    end
  end
end
