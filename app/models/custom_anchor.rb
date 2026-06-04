# A user-pinned point on the map used as a trip anchor (polymorphic, alongside Place/Neighborhood).
# Exposes the same name/latitude/longitude interface the anchor pipeline reads, so it flows through
# AnchorTravelTimesService, TravelToAnchor caching, and the map's anchor marker unchanged.
class CustomAnchor < ApplicationRecord
  has_many :inquiries, as: :anchor
  has_many :travel_to_anchors, as: :anchor, dependent: :destroy

  def name
    label.presence || "Pinned location"
  end
end
