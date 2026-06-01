class PropertiesController < ApplicationController
  def show
    @property = Property.find(params[:id])
    if session[:inquiry_id] && (inquiry = Inquiry.find_by(id: session[:inquiry_id]))
      @checkin  = inquiry.check_in&.strftime("%Y-%m-%d")
      @checkout = inquiry.check_out&.strftime("%Y-%m-%d")
    end
  end

  # app/controllers/properties_controller.rb
  def toggle_favorite
    @property = Property.find(params[:id])
    if current_user.favorited?(@property)
      current_user.unfavorite(@property)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("favorite_#{@property.id}")
        end
        format.html { redirect_back fallback_location: root_path }
      end
    else
      current_user.favorite(@property)
      redirect_back fallback_location: root_path
    end
  end

  def favorites
    @favorite_properties = current_user.all_favorited.select { |item| item.is_a?(Property) }
  end
end
