class ApplicationController < ActionController::Base
  def set_currency
    session[:currency] = params[:currency]
    redirect_back fallback_location: root_path
  end
end
