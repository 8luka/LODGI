class PlacesController < ApplicationController
  def search
    places =
      Place.where(
        category: params[:category]
      )

    render json:
      places.select(
        :id,
        :name,
        :latitude,
        :longitude,
        :rating,
        :photos,
        :category
      )
  end
end
