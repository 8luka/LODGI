class MapsController < ApplicationController
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
    @properties = JSON.generate(
      @properties_records.map { |property| property_payload(property, travel_times) }
    )
    @neighborhoods = Neighborhood.all
  end

  private

  # One property's data for the map JS: map/filter fields plus the scoring inputs
  # (score_inputs jsonb + cached travel time to the anchor, nil when uncached/no anchor).
  def property_payload(property, travel_times)
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
      travel_time_to_anchor: travel_times[property.id]
    }
  end
end
