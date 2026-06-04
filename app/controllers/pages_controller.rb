class PagesController < ApplicationController
  def home
    @neighborhoods = Neighborhood.all
    @properties_count = Property.count
    @vendors = Property.select(:vendor, :vendor_image).group(:vendor, :vendor_image)
  end
end
