class NeighborhoodsController < ApplicationController
  def show
    @neighborhood = Neighborhood.find(params[:id])

    # Per-listing fit-score inputs so the cards can show the visitor's score (computed client-side
    # by the same engine as the map, with the same all-listings normalization basis so scores match).
    # The score itself only renders when the visitor has set priorities — see nb_scores_controller.
    inquiry = session[:inquiry_id] && Inquiry.find_by(id: session[:inquiry_id])
    travel_times = inquiry&.anchor ? TravelToAnchor.where(anchor: inquiry.anchor).pluck(:property_id, :travel_time).to_h : {}
    normalized = ScoreNormalizer.call(Property.all, anchor_travel_times: travel_times)
    @nb_normalized_inputs = @neighborhood.properties.pluck(:id).index_with { |id| normalized[id] || {} }
  end
end
