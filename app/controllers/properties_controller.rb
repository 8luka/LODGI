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

  # Favorites comparison workspace. Mirrors MapsController#map's data prep so the cards can be
  # live-scored client-side by the same engine + priorities panel: per-property scoring inputs,
  # the current anchor + its cached travel times, and precomputed "your life from here" rows.
  def favorites
    favorite_ids = current_user ? current_user.all_favorited.select { |i| i.is_a?(Property) }.map(&:id) : []
    @favorite_properties = Property.includes(:neighborhood, :places)
                                   .where(id: favorite_ids)
                                   .order(:price)

    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    @anchor = nil
    travel_times = {}
    if inquiry&.anchor.present?
      @anchor = { id: inquiry.anchor.id, name: inquiry.anchor.name,
                  latitude: inquiry.anchor.latitude, longitude: inquiry.anchor.longitude }
      travel_times = TravelToAnchor.where(anchor: inquiry.anchor).pluck(:property_id, :travel_time).to_h
    end

    # Same all-listings normalization basis as the map/show so a card's score matches the map's.
    normalized = ScoreNormalizer.call(Property.all, anchor_travel_times: travel_times)
    @normalized_inputs = @favorite_properties.to_h { |p| [p.id, normalized[p.id] || {}] }

    ceiling = Property.maximum(:price).to_f
    @max_price = ceiling.positive? ? (ceiling / 10_000).ceil * 10_000 : 500_000
    @scoring_v2 = MapsController::SCORING_V2

    @favorites_payload = JSON.generate(
      @favorite_properties.map { |property| favorite_payload(property, travel_times) }
    )
  end

  def popup
    @property = Property.find(params[:id])
    render layout: false
  end

  private

  # One favorited property's data for the comparison cards' client-side scoring + rows.
  # life_rows ({ category => { icon, text } }) is precomputed server-side (reuses the show page's
  # "your life from here" helper); the client decides which rows are shown vs tucked away.
  def favorite_payload(property, travel_times)
    {
      id: property.id,
      price: property.price,
      availability: property.availability,
      score_inputs: property.score_inputs,
      travel_time_to_anchor: travel_times[property.id],
      life_rows: helpers.life_rows_by_category(property)
    }
  end

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
