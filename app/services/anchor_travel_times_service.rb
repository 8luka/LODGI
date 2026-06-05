require Rails.root.join("lib/distance_helper_v2_new")

# Computes and caches travel time FROM an anchor TO each property, using Google's Routes API
# computeRouteMatrix.
#
# Mode is a radius hybrid (Google's APIs do NOT provide transit/train routing in Japan, so transit
# is not an option here — confirmed: drive/walk work, transit returns ZERO_RESULTS nationwide):
#   • within WALK_RADIUS_M of the anchor → WALK time  (realistic; you'd walk, not take a train)
#   • beyond it                          → DRIVE time (a stand-in for the train ride we can't get)
# travel_time is stored in whole minutes either way; the score's commute term consumes it directly.
#
# Gap-filling cache: only properties without a cached row for this anchor are fetched, so re-selecting
# the same anchor costs no API call, and adding new properties later only fetches the new ones.
# Results live in the travel_to_anchors table.
#
# Anchor is polymorphic — a Place (landmark/campus) or a Neighborhood; both carry latitude/longitude.
# Never raises into the caller: a missing key or API failure is logged and skipped so the user's
# inquiry submit always succeeds.
class AnchorTravelTimesService
  # ── Formula switch ──────────────────────────────────────────────────────────
  # true  → haversine walking estimate (straight_line ÷ 80 min); no API call is made.
  # false → Google Routes API (WALK within WALK_RADIUS_M, DRIVE beyond).
  USE_LOCAL_FORMULA = true

  COMPUTE_ROUTE_MATRIX_URL = "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix".freeze
  FIELD_MASK = "originIndex,destinationIndex,duration,condition".freeze
  # One origin (the anchor) × up to 100 destinations per call stays within the matrix element cap
  # for every travel mode.
  MAX_DESTINATIONS_PER_CALL = 100
  # Walk for anchors within this straight-line distance; drive beyond. Tunable — ~1.2 km ≈ a 15-min
  # walk, the point where f_commute stops treating a walk as an "effortless" commute.
  WALK_RADIUS_M = 1200
  # If a CustomAnchor within this radius already has full travel-time coverage, copy its rows
  # rather than hitting the Routes API. 300 m keeps you within the same city block in Tokyo —
  # travel-time differences are ≤ 1-2 min, score ranking is effectively unchanged.
  NEARBY_BORROW_RADIUS_M = 300

  def self.call(anchor)
    new(anchor).call
  end

  def initialize(anchor)
    @anchor = anchor
  end

  def call
    return if @anchor.nil? || @anchor.latitude.nil? || @anchor.longitude.nil?

    if USE_LOCAL_FORMULA
      compute_local
      refresh_seed_file
      return
    end

    routes_key = ENV.fetch("ROUTES_API", nil)
    if routes_key.blank?
      Rails.logger.warn("[AnchorTravelTimes] ROUTES_API not set — skipping travel-time computation for #{anchor_label}")
      return
    end

    # If a nearby fully-covered CustomAnchor exists, copy its rows — no API call needed.
    # Exits before refresh_seed_file, so borrowed anchors are intentionally not seeded:
    # the donor is already in the seed and the borrow logic re-fires after any DB reset.
    return if borrow_from_nearby?

    missing = missing_properties
    if missing.empty?
      Rails.logger.info("[AnchorTravelTimes] #{anchor_label}: 0 missing — no API call")
      return
    end

    # Near properties get a walking time, far ones a driving time (transit isn't available in Japan).
    walk_props, drive_props = missing.partition { |property| within_walk_radius?(property) }
    process_group(walk_props, "WALK", routes_key)
    process_group(drive_props, "DRIVE", routes_key)

    # Persist the freshly-cached times to the seed file so a first-time anchor (e.g. a user's map
    # pin) is captured without manually running the rake. Only reached when there was missing work.
    refresh_seed_file
  end

  private

  # Best-effort full re-dump of the travel_to_anchors table to its seed file. Never raises into the
  # caller — a read-only FS or any write error is logged and skipped so the user's inquiry succeeds.
  def refresh_seed_file
    TravelToAnchorsSeedWriter.call
  rescue => e
    Rails.logger.warn("[AnchorTravelTimes] seed refresh failed for #{anchor_label}: #{e.message}")
  end

  # If another CustomAnchor within NEARBY_BORROW_RADIUS_M has full travel-time coverage for all
  # current properties, copy its rows to @anchor and return true (skipping the Routes API).
  # Only borrows if coverage is complete — partial donors are ignored and the API fills gaps.
  def borrow_from_nearby?
    return false unless @anchor.is_a?(CustomAnchor)

    property_ids = Property.where.not(latitude: nil, longitude: nil).pluck(:id).to_set
    return false if property_ids.empty?

    donor = CustomAnchor.where.not(id: @anchor.id).find do |ca|
      next false if DistanceHelperV2New.haversine_meters(
        @anchor.latitude, @anchor.longitude, ca.latitude, ca.longitude
      ) > NEARBY_BORROW_RADIUS_M

      covered = TravelToAnchor.where(anchor: ca).pluck(:property_id).to_set
      property_ids.subset?(covered)
    end

    return false unless donor

    have = TravelToAnchor.where(anchor: @anchor).pluck(:property_id).to_set
    rows = TravelToAnchor.where(anchor: donor)
                         .where.not(property_id: have.to_a)
                         .map do |r|
      { anchor_type: "CustomAnchor", anchor_id: @anchor.id,
        property_id: r.property_id, travel_time: r.travel_time,
        created_at: Time.current, updated_at: Time.current }
    end

    TravelToAnchor.insert_all(rows) if rows.any?
    Rails.logger.info("[AnchorTravelTimes] #{anchor_label}: borrowed #{rows.size} rows " \
                      "from CustomAnchor##{donor.id} (within #{NEARBY_BORROW_RADIUS_M}m)")
    true
  end

  # Haversine walking estimate: straight-line meters ÷ 80 m/min.
  def compute_local
    missing_properties.each do |property|
      meters = DistanceHelperV2New.haversine_meters(
        @anchor.latitude, @anchor.longitude,
        property.latitude, property.longitude
      )
      walk_time = (meters / 80.0).round
      TravelToAnchor.find_or_create_by!(anchor: @anchor, property: property) do |r|
        r.travel_time = walk_time
      end
    end
  end

  # Properties that have coordinates but no cached travel time for this anchor yet.
  def missing_properties
    cached_ids = TravelToAnchor.where(anchor: @anchor).pluck(:property_id)
    Property.where.not(id: cached_ids)
            .where.not(latitude: nil, longitude: nil)
            .to_a
  end

  def within_walk_radius?(property)
    DistanceHelperV2New.haversine_meters(
      @anchor.latitude, @anchor.longitude, property.latitude, property.longitude
    ) < WALK_RADIUS_M
  end

  def process_group(properties, mode, routes_key)
    return if properties.empty?

    properties.each_slice(MAX_DESTINATIONS_PER_CALL) do |batch|
      fetch_and_persist_batch(batch, mode, routes_key)
      sleep 0.15 # be courteous to the API between batches
    end
  end

  def fetch_and_persist_batch(batch, mode, routes_key)
    response = HTTParty.post(
      COMPUTE_ROUTE_MATRIX_URL,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => routes_key,
        "X-Goog-FieldMask" => FIELD_MASK
      },
      body: request_body(batch, mode).to_json
    )

    unless response.success?
      Rails.logger.warn("[AnchorTravelTimes] #{anchor_label} (#{mode}): HTTP #{response.code} — " \
                        "#{response.parsed_response.inspect[0, 300]} (batch skipped)")
      return
    end

    persist_results(batch, Array(response.parsed_response))
  end

  def request_body(batch, mode)
    body = {
      origins: [{ waypoint: { location: { latLng: latlng(@anchor) } } }],
      destinations: batch.map { |property| { waypoint: { location: { latLng: latlng(property) } } } },
      travelMode: mode
    }
    # Traffic-unaware keeps driving numbers stable/comparable across runs (no time-of-day variance);
    # WALK ignores this field.
    body[:routingPreference] = "TRAFFIC_UNAWARE" if mode == "DRIVE"
    body
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
