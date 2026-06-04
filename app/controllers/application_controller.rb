class ApplicationController < ActionController::Base
  before_action :load_inquiry_from_session

  def set_currency
    session[:currency] = params[:currency]
    redirect_back fallback_location: map_path
  end

  private

  def load_inquiry_from_session
    inquiry = Inquiry.find_by(id: session[:inquiry_id]) if session[:inquiry_id]

    unless inquiry
      inquiry = Inquiry.create!(
        user: current_user,
        commute_weight: 0,
        quiet_weight: 0,
        station_weight: 0,
        selected_places: []
      )
      session[:inquiry_id] = inquiry.id
    end

    @checkin         = inquiry.check_in&.strftime("%Y-%m-%d")
    @checkout        = inquiry.check_out&.strftime("%Y-%m-%d")
    @guests          = inquiry.guests
    @trip_type       = inquiry.why_visit || "visiting"
    @commute_weight  = inquiry.commute_weight.to_i   # nil.to_i = 0 after a clear
    @quiet_weight    = inquiry.quiet_weight.to_i
    @station_weight  = inquiry.station_weight.to_i
    @selected_places = inquiry.selected_places || []
    @selected_anchor = anchor_record_to_hash(inquiry.anchor) if inquiry.anchor
  end

  def after_sign_in_path_for(resource)
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      inquiry.update(user: resource) if inquiry.user_id.nil?
    end
    super
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
    when CustomAnchor
      { "id" => "pinned-#{record.id}", "name" => record.name,
        "categories" => ["pinned"], "lat" => record.latitude, "lng" => record.longitude }
    end
  end
end
