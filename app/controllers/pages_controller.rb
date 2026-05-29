class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    @properties = JSON.generate(Property.select(
      :id,
      :name,
      :latitude,
      :longitude,
      :layout,
      :price,
      :stations,
      :images
    ).as_json(except: [:id]))

    @neighborhoods = Neighborhood.all
  end
end
