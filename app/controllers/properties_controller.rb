class PropertiesController < ApplicationController
  def show
    @property = Property.find(params[:id])
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      @checkin  = inquiry.check_in&.strftime("%Y-%m-%d")
      @checkout = inquiry.check_out&.strftime("%Y-%m-%d")
    end
  end
end
