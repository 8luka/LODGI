# Computes and caches transit (train) travel time FROM an anchor TO each property,
# using Google's Routes API computeRouteMatrix in TRANSIT mode.
#
# Gap-filling cache: only properties without a cached row for this anchor are fetched,
# so re-selecting the same anchor costs no API call, and adding new properties later only
# fetches the new ones. Results live in the travel_to_anchors table.
#
# Anchor is polymorphic — a Place (landmark/campus) or a Neighborhood; both carry
# latitude/longitude. Never raises into the caller: a missing key or API failure is logged
# and skipped so the user's inquiry submit always succeeds.
class AnchorTravelTimesService
  COMPUTE_ROUTE_MATRIX_URL = "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix".freeze
  FIELD_MASK = "originIndex,destinationIndex,duration,condition".freeze
  # computeRouteMatrix caps a TRANSIT request at 100 elements (origins x destinations).
  # With one origin (the anchor) that means at most 100 destinations per call.
  MAX_DESTINATIONS_PER_CALL = 100

  def self.call(anchor)
    new(anchor).call
  end

  def initialize(anchor)
    @anchor = anchor
  end

  def call
    return if @anchor.nil? || @anchor.latitude.nil? || @anchor.longitude.nil?

    routes_key = ENV.fetch("ROUTES_API", nil)
    if routes_key.blank?
      Rails.logger.warn("[AnchorTravelTimes] ROUTES_API not set — skipping travel-time computation for #{anchor_label}")
      return
    end

    missing = missing_properties
    if missing.empty?
      Rails.logger.info("[AnchorTravelTimes] #{anchor_label}: 0 missing — no API call")
      return
    end

    missing.each_slice(MAX_DESTINATIONS_PER_CALL) do |batch|
      fetch_and_persist_batch(batch, routes_key)
      sleep 0.15 # be courteous to the API between batches
    end
  end

  private

  # Properties that have coordinates but no cached travel time for this anchor yet.
  def missing_properties
    cached_ids = TravelToAnchor.where(anchor: @anchor).pluck(:property_id)
    Property.where.not(id: cached_ids)
            .where.not(latitude: nil, longitude: nil)
            .to_a
  end

  def fetch_and_persist_batch(batch, routes_key)
    response = HTTParty.post(
      COMPUTE_ROUTE_MATRIX_URL,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => routes_key,
        "X-Goog-FieldMask" => FIELD_MASK
      },
      body: request_body(batch).to_json
    )

    unless response.success?
      Rails.logger.warn("[AnchorTravelTimes] #{anchor_label}: HTTP #{response.code} — " \
                        "#{response.parsed_response.inspect[0, 300]} (batch skipped)")
      return
    end

    persist_results(batch, Array(response.parsed_response))
  end

  def request_body(batch)
    {
      origins: [{ waypoint: { location: { latLng: latlng(@anchor) } } }],
      destinations: batch.map { |property| { waypoint: { location: { latLng: latlng(property) } } } },
      travelMode: "TRANSIT"
      # departureTime omitted → the API uses "now". A future refinement could pin a
      # representative weekday-morning time for stable, comparable transit numbers.
    }
  end

  # Insert one row per destination — including a nil travel_time when no route exists, so a
  # known-bad pair is never re-queried. destinationIndex maps an element back to its property.
  def persist_results(batch, elements)
    TravelToAnchor.transaction do
      elements.each do |element|
        index = element["destinationIndex"]
        property = batch[index]
        next if property.nil?

        TravelToAnchor.create!(
          anchor: @anchor,
          property: property,
          travel_time: travel_minutes(element)
        )
      end
    end
  end

  def travel_minutes(element)
    return nil unless element["condition"] == "ROUTE_EXISTS"

    duration = element["duration"] # e.g. "1234s"
    return nil if duration.blank?

    (duration.to_i / 60.0).round
  end

  def latlng(record)
    { latitude: record.latitude, longitude: record.longitude }
  end

  def anchor_label
    "#{@anchor.class.name}##{@anchor.id}"
  end
end
