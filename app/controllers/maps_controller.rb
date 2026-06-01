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

  end
end
