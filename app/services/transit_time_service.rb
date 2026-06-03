# app/services/transit_time_service.rb

class TransitTimeService
  include HTTParty

  BASE_URL = "https://maps.googleapis.com/maps/api/directions/json"

  def self.travel_time(origin:, destination:)
    response = get(
      BASE_URL,
      query: {
        origin: origin,
        destination: destination,
        mode: "transit",
        transit_mode: "train",
        key: ENV.fetch("MAPS_JS_API", nil)
      }
    )

    data = response.parsed_response
    p data
    return nil if data["routes"].blank?

    leg = data["routes"][0]["legs"][0]

    {
      duration_text: leg["duration"]["text"],
      duration_seconds: leg["duration"]["value"]
    }
  end
end
