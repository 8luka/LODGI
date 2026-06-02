class Place < ApplicationRecord
  belongs_to :neighborhood, optional: true
  belongs_to :property, optional: true
  has_many :inquiries, as: :anchor
  has_many :travel_to_anchors, as: :anchor, dependent: :destroy
end
