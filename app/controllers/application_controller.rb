class ApplicationController < ActionController::Base
  def set_currency
    session[:currency] = params[:currency]
    redirect_back fallback_location: map_path
  end
end
