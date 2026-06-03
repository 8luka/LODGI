class TravelToAnchor < ApplicationRecord
  belongs_to :anchor, polymorphic: true # Place or Neighborhood
  belongs_to :property
end
