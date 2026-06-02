class ApplicationController < ActionController::Base
  before_action :load_inquiry_from_session

  def set_currency
    session[:currency] = params[:currency]
    redirect_back fallback_location: map_path
  end

  private

  def load_inquiry_from_session
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      @checkin         = inquiry.check_in&.strftime("%Y-%m-%d")
      @checkout        = inquiry.check_out&.strftime("%Y-%m-%d")
      @guests          = inquiry.guests
      @trip_type       = inquiry.why_visit
      @commute_weight  = inquiry.commute_weight&.to_i
      @quiet_weight    = inquiry.quiet_weight&.to_i
      @station_weight  = inquiry.station_weight&.to_i
      @selected_places = inquiry.selected_places || []
      @selected_anchor = anchor_record_to_hash(inquiry.anchor) if inquiry.anchor
    end
    @trip_type ||= "visiting"

    # Fall back to trip-type defaults when no inquiry / legacy nil weights.
    # (||= preserves a real 0, since 0 is truthy in Ruby.)
    defaults = Inquiry.default_weights(@trip_type)
    @commute_weight  ||= defaults[:commute_weight]
    @quiet_weight    ||= defaults[:quiet_weight]
    @station_weight  ||= defaults[:station_weight]
    @selected_places ||= []
  end

  def anchor_record_to_hash(record)
    return nil unless record

    case record
    when Neighborhood
      categories = ["neighborhood"]
      categories << "landmark" if record.is_landmark
      categories << "work"     if record.is_workplace
      { "id" => record.name.parameterize, "name" => record.name,
        "categories" => categories, "lat" => record.latitude, "lng" => record.longitude }
    when Place
      { "id" => record.name.parameterize, "name" => record.name,
        "categories" => [record.category], "lat" => record.latitude, "lng" => record.longitude }
    end
  end
end
