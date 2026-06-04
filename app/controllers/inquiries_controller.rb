class InquiriesController < ApplicationController
  # Slider data-key -> "#{key}_weight" column. Allowlist for update_weights.
  WEIGHT_KEYS = %w[commute quiet station].freeze

  # Allowlist for update_selected_places. Must match data-place-label values in the ERB.
  ALLOWED_PLACE_LABELS = ["convenience stores", "supermarkets", "ATMs", "cafes",
                          "restaurants", "bars", "parks", "gyms", "tourist spots"].freeze

  def clear
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      inquiry.update(
        check_in: nil,
        check_out: nil,
        guests: nil,
        why_visit: nil,
        anchor: nil,
        commute_weight: nil,
        quiet_weight: nil,
        station_weight: nil,
        selected_places: []
      )
    end
    redirect_back(fallback_location: map_path)
  end

  def create
    inquiry = Inquiry.find_by(id: session[:inquiry_id])

    inquiry.assign_attributes(
      user: current_user,
      check_in: params[:checkin],
      check_out: params[:checkout],
      guests: params[:guests].presence&.to_i,
      why_visit: params[:trip_type].presence
    )

    # Apply trip-type weight defaults when the trip type changes.
    # On first form submit why_visit changes from nil → type, so defaults always apply then.
    inquiry.assign_attributes(Inquiry.default_weights(inquiry.why_visit)) if inquiry.why_visit_changed?

    inquiry.selected_places = []
    assign_anchor!(inquiry, resolve_anchor(params[:anchor]))

    redirect_to map_path
  end

  # Set the anchor to a user-pinned point on the map (lat/lng) instead of a curated Place/
  # Neighborhood. Shares assign_anchor! with #create, so commute-weight recompute and travel-time
  # caching behave identically. The JS reloads /map on success (reload-after-pin).
  def set_pinned_anchor
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    lat = params[:lat].presence&.to_f
    lng = params[:lng].presence&.to_f
    return head :bad_request unless inquiry && lat && lng

    # Round before lookup so re-pinning the same spot reuses the row (and its cached travel times).
    anchor = CustomAnchor.find_or_create_by(latitude: lat.round(4), longitude: lng.round(4)) do |a|
      a.label = params[:label].presence
    end
    # sync: a pin is always a first-time anchor, so cache its travel times now. The JS opens the
    # name form immediately on click (without awaiting this), so the ~2s Routes call overlaps with
    # the user typing a name — and is done by the time they save and the page reloads.
    assign_anchor!(inquiry, anchor, sync: true)
    head :ok
  end

  # Rename the current map-pinned anchor (optional free-text name). Reflected everywhere the anchor
  # name is shown (map popup, navbar summary) after the reload the JS does on save. Blank clears the
  # label, falling back to CustomAnchor#name's "Pinned location" default.
  def rename_anchor
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    anchor = inquiry&.anchor
    if anchor.is_a?(CustomAnchor)
      anchor.update(label: params[:name].presence)
      refresh_anchor_seed
    end
    head :ok
  end

  # Replace the full selected_places array (one call per toggle, sends current full set).
  def update_selected_places
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    if inquiry
      places = Array(params[:selected_places]).map(&:to_s).select { |p| ALLOWED_PLACE_LABELS.include?(p) }
      inquiry.update(selected_places: places)
    end
    head :no_content
  end

  # Persist a single slider move (data-key + position) onto the session inquiry.
  def update_weights
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    inquiry.update("#{params[:key]}_weight" => params[:value].to_i) if inquiry && WEIGHT_KEYS.include?(params[:key])
    head :no_content
  end

  def update_dates
    inquiry =
      session[:inquiry_id] &&
      Inquiry.find_by(
        id: session[:inquiry_id]
      )

    if inquiry

      inquiry.update(
        check_in: params[:check_in],
        check_out: params[:check_out]
      )

    end

    head :no_content
  end

  private

  # Single path for setting an inquiry's anchor — used by both #create (curated anchor) and
  # #set_pinned_anchor (map pin), so API-call volume and weight logic stay identical.
  #   • Easy-commute weight: anchor set → trip-type default (visiting 1, business/education 2),
  #     no anchor → 0 (which also hides the Easy-commute slider on /map).
  #   • Travel-time cache: enqueued whenever an anchor is present. The service's gap-filling cache
  #     makes a repeat anchor a no-op and only fetches properties added since last time.
  def assign_anchor!(inquiry, anchor_record, sync: false)
    inquiry.anchor = anchor_record
    inquiry.commute_weight =
      anchor_record.present? ? Inquiry.default_weights(inquiry.why_visit)[:commute_weight] : 0
    inquiry.save
    return if anchor_record.blank?

    # sync caches inline (Routes API call before we respond) so the caller's reload already has
    # commute data — used by map pins, which are always first-time anchors. Curated anchors stay
    # async: they're usually pre-cached, so the gap-filling job is a fast no-op with no user wait.
    if sync
      AnchorTravelTimesService.call(anchor_record)
    else
      AnchorTravelTimesJob.perform_later(anchor_record)
    end
  end

  # Re-dump the travel-time seed so a renamed pin's label persists across a DB reset (the seed
  # stores the CustomAnchor label). Best-effort: never break the rename on a write failure.
  def refresh_anchor_seed
    TravelToAnchorsSeedWriter.call
  rescue => e
    Rails.logger.warn("[Inquiries] anchor seed refresh failed: #{e.message}")
  end

  # The form sends anchor as"shinjuku" so an instance must be found instead. A map-pinned anchor
  # round-trips as "pinned-<id>" (see anchor_record_to_hash) so re-submitting the navbar form
  # with a pin active preserves it instead of wiping the anchor.
  def resolve_anchor(slug)
    return nil if slug.blank?
    return CustomAnchor.find_by(id: slug.delete_prefix("pinned-")) if slug.start_with?("pinned-")

    Neighborhood.all.find { |n| n.name.parameterize == slug } ||
      Place.all.find { |p| p.name.parameterize == slug }
  end
end
