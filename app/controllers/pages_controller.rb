class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    @properties = JSON.generate(
      Property.includes(:neighborhood).map do |property|
        {
          id: property.id,
          name: property.name,
          latitude: property.latitude,
          longitude: property.longitude,
          layout: property.layout,
          price: property.price,
          stations: property.stations,
          images: property.images,
          neighborhood_name: property.neighborhood.name
        }
      end
    )
    @neighborhoods = Neighborhood.all
  end
end
