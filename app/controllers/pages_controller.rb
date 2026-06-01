class PagesController < ApplicationController
  def home
    @neighborhoods = Neighborhood.all
  end
end
