class PlacesController < ApplicationController
  def search
    category = params[:category]
    center_lat = params[:center_lat]
    center_lng = params[:center_lng]
    radius = params[:radius]

    response = HTTParty.get(
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
      query: {
        key: ENV.fetch("PLACES_API", nil),
        location: "#{center_lat},#{center_lng}",
        radius: radius,
        type: category
      }
    )

    results = response.parsed_response["results"]
    places = results.map do |place|
      {
        name: place["name"],
        latitude: place["geometry"]["location"]["lat"],
        longitude: place["geometry"]["location"]["lng"],
        rating: place["rating"]
      }
    end
    render json: places
  end
end
