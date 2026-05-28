class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def set_currency
    session[:currency] = params[:currency]
    redirect_back fallback_location: root_path
  end
end
