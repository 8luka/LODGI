class MapsController < ApplicationController
  def map
    # Ordered by price as the stable placeholder ranking until the fit-score
    @properties_records = Property.includes(:neighborhood).order(:price)
    @properties = JSON.generate(
      @properties_records.map do |property|
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
          availability: property.availability
        }
      end
    )
    @neighborhoods = Neighborhood.all

    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      @checkin         = inquiry.check_in&.strftime("%Y-%m-%d")
      @checkout        = inquiry.check_out&.strftime("%Y-%m-%d")
      @guests          = inquiry.guests
      @trip_type       = inquiry.why_visit
      @selected_anchor = anchor_record_to_hash(inquiry.anchor) if inquiry.anchor
    end

    @trip_type ||= "visiting"
  end

  private

  # This is overkill for now. BUT when we get to a scoring system it won't be

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
