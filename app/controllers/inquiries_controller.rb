class InquiriesController < ApplicationController
  # Slider data-key -> "#{key}_weight" column. Allowlist for update_weights.
  WEIGHT_KEYS = %w[commute quiet station].freeze

  # Allowlist for update_selected_places. Must match data-place-label values in the ERB.
  ALLOWED_PLACE_LABELS = ["convenience stores", "supermarkets", "ATMs", "cafes",
                          "restaurants", "bars", "parks", "gyms", "tourist spots"].freeze

  def clear
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      inquiry.update(
        check_in:        nil,
        check_out:       nil,
        guests:          nil,
        why_visit:       nil,
        anchor:          nil,
        commute_weight:  nil,
        quiet_weight:    nil,
        station_weight:  nil,
        selected_places: []
      )
    end
    redirect_back(fallback_location: map_path)
  end

  def create
    inquiry = Inquiry.find_by(id: session[:inquiry_id])

    inquiry.assign_attributes(
      user: current_user,
      check_in:  params[:checkin],
      check_out: params[:checkout],
      guests:    params[:guests].presence&.to_i,
      why_visit: params[:trip_type].presence,
      anchor:    resolve_anchor(params[:anchor])
    )

    # Apply trip-type weight defaults when the trip type changes.
    # On first form submit why_visit changes from nil → type, so defaults always apply then.
    inquiry.assign_attributes(Inquiry.default_weights(inquiry.why_visit)) if inquiry.why_visit_changed?

    # Easy-commute weight scores travel time to the anchor, so it is recomputed on every
    # submit from anchor presence (independent of why_visit_changed?, so adding/removing an
    # anchor without switching trip type is handled):
    #   anchor set → trip-type default (visiting 1, business/education 2)
    #   no anchor  → 0 (also hides the Easy-commute slider on /map)
    inquiry.commute_weight =
      inquiry.anchor.present? ? Inquiry.default_weights(inquiry.why_visit)[:commute_weight] : 0

    inquiry.selected_places = []
    inquiry.save

    # Cache transit travel time from the anchor to every property. Enqueued on every
    # submit-with-anchor (not only when the anchor changes): the service's cache check makes
    # a repeat anchor a no-op, and running unconditionally fills the gap for any properties
    # added since last time.
    AnchorTravelTimesJob.perform_later(inquiry.anchor) if inquiry.anchor.present?

    redirect_to map_path
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
    if inquiry && WEIGHT_KEYS.include?(params[:key])
      inquiry.update("#{params[:key]}_weight" => params[:value].to_i)
    end
    head :no_content
  end

  private

  # The form sends anchor as"shinjuku" so an instance must be found instead
  def resolve_anchor(slug)
    return nil if slug.blank?

    Neighborhood.all.find { |n| n.name.parameterize == slug } ||
      Place.all.find { |p| p.name.parameterize == slug }
  end
end
