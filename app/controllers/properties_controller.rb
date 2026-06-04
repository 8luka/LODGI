class PropertiesController < ApplicationController
  def show
    @property = Property.find(params[:id])

    inquiry = Inquiry.find_by(id: session[:inquiry_id]) if session[:inquiry_id]
    if inquiry
      @checkin  = inquiry.check_in&.strftime("%Y-%m-%d")
      @checkout = inquiry.check_out&.strftime("%Y-%m-%d")
    end

    load_fit_summary(inquiry&.anchor)
  end

  def toggle_favorite
    @property = Property.find(params[:id])

    if current_user.favorited?(@property)
      current_user.unfavorite(@property)
    else
      current_user.favorite(@property)
    end

    respond_to do |format|
      format.turbo_stream do
        if params[:source] == "favorites"
          render turbo_stream: turbo_stream.remove("property_#{@property.id}")
        else
          render turbo_stream: turbo_stream.replace(
            "favorite_#{@property.id}",
            partial: "properties/favorite_button",
            locals: {
              property: @property
            }
          )
        end
      end

      format.html do
        redirect_back fallback_location: root_path
      end
    end
  end

  def favorites
    @favorite_properties =
      current_user.all_favorited.select { |item| item.is_a?(Property) }
  end

  def popup
    @property = Property.find(params[:id])
    render layout: false
  end

  private

  # Fit-summary banner data for the show page: this property's normalized score inputs (same
  # all-listings basis as the map, so the score matches) + its cached travel time to the
  # current anchor. The view's fit-summary Stimulus controller computes the score client-side.
  def load_fit_summary(anchor)
    travel_times = anchor ? TravelToAnchor.where(anchor: anchor).pluck(:property_id, :travel_time).to_h : {}
    @fit_travel_time = travel_times[@property.id]
    normalized = ScoreNormalizer.call(Property.all, anchor_travel_times: travel_times)
    @fit_normalized = normalized[@property.id] || {}
  end
end
