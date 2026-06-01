class PlacesController < ApplicationController
  def search
    places =
      Place.where(
        category: params[:category]
      )
           .where(
             latitude:
               params[:south]..params[:north]
           )
           .where(
             longitude:
               params[:west]..params[:east]
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
