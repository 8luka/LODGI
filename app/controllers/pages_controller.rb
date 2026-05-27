class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
    @properties = JSON.generate(Property.select(:latitude, :longitude).as_json(except: [:id]))
  end
end
