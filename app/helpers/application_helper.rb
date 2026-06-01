module ApplicationHelper
  # Trip anchors built from DB records. Each anchor:
  # { "id", "name", "categories" => [..], "lat", "lng" }.
  def trip_anchors
    @trip_anchors ||= begin
      neighborhood_anchors = Neighborhood.all.map do |n|
        categories = ["neighborhood"]
        categories << "landmark" if n.is_landmark
        categories << "work" if n.is_workplace
        {
          "id" => n.name.parameterize,
          "name" => n.name,
          "categories" => categories,
          "lat" => n.latitude,
          "lng" => n.longitude
        }
      end

      place_anchors = Place.all.map do |p|
        {
          "id" => p.name.parameterize,
          "name" => p.name,
          "categories" => [p.category],
          "lat" => p.latitude,
          "lng" => p.longitude
        }
      end

      neighborhood_anchors + place_anchors
    end
  end

  # Returns true when the property's availability string is on or before checkin_date.
  # availability is "now", "June 7th", "August 20th", etc.
  def available_for_checkin?(availability, checkin_date)
    return true if availability.to_s.downcase == "now"
    return false if checkin_date.nil?
    clean = availability.to_s.gsub(/(\d+)(st|nd|rd|th)/i, '\1')
    avail_date = Date.parse("#{clean} #{checkin_date.year}")
    avail_date <= checkin_date
  rescue ArgumentError
    false
  end

  # Look up a single anchor by its slug id (nil when absent / not given).
  def trip_anchor(id)
    return nil if id.blank?
    trip_anchors.find { |a| a["id"] == id }
  end
end
