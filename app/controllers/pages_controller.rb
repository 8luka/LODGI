class PagesController < ApplicationController
  def home
    @neighborhoods = Neighborhood.all
    @properties_count = Property.count
  end
end
