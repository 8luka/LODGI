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
      why_visit: params[:trip_type].presence,
      anchor: resolve_anchor(params[:anchor])
    )

    # Apply trip-type weight defaults when the trip type changes.
    # On first form submit why_visit changes from nil → type, so defaults always apply then.
    inquiry.assign_attributes(Inquiry.default_weights(inquiry.why_visit)) if inquiry.why_visit_changed?

    # Easy-commute weight scores travel time to the anchor; with no anchor it is
    # meaningless. Force it to 0 (which also hides the Easy-commute slider on /map)
    # regardless of trip type.
    inquiry.commute_weight = 0 if inquiry.anchor.blank?

    inquiry.selected_places = []
    inquiry.save

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

  # The form sends anchor as"shinjuku" so an instance must be found instead
  def resolve_anchor(slug)
    return nil if slug.blank?

    Neighborhood.all.find { |n| n.name.parameterize == slug } ||
      Place.all.find { |p| p.name.parameterize == slug }
  end
end
