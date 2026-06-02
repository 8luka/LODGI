class InquiriesController < ApplicationController
  # Slider data-key -> "#{key}_weight" column. Allowlist for update_weights.
  WEIGHT_KEYS = %w[commute quiet station].freeze

  # Allowlist for update_selected_places. Must match data-place-label values in the ERB.
  ALLOWED_PLACE_LABELS = ["convenience stores", "supermarkets", "ATMs", "cafes",
                          "restaurants", "bars", "parks", "gyms", "tourist spots"].freeze

  def clear
    if session[:inquiry_id]
      Inquiry.find_by(id: session[:inquiry_id])&.destroy
      session.delete(:inquiry_id)
    end
    redirect_back(fallback_location: map_path)
  end

  def create
    inquiry = session[:inquiry_id] ? Inquiry.find_by(id: session[:inquiry_id]) : nil
    inquiry ||= Inquiry.new

    weights_unset = inquiry.commute_weight.nil?

    inquiry.assign_attributes(
      user: current_user,
      check_in: params[:checkin],
      check_out: params[:checkout],
      guests: params[:guests].presence&.to_i,
      why_visit: params[:trip_type].presence,
      anchor: resolve_anchor(params[:anchor])
    )

    # Reset weights to the trip-type defaults only when the trip type changed
    # (or was never set) — so date-only re-searches keep the user's slider tweaks.
    if weights_unset || inquiry.why_visit_changed?
      inquiry.assign_attributes(Inquiry.default_weights(inquiry.why_visit))
    end

    inquiry.selected_places = []
    inquiry.save
    session[:inquiry_id] = inquiry.id

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
