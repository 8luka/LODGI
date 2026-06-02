class Property < ApplicationRecord
  belongs_to :neighborhood
  has_many :property_amenities, dependent: :destroy
  has_many :amenities, through: :property_amenities
  has_many :reviews, dependent: :destroy
  has_many :inquiries
  has_many :places
  has_many :travel_to_anchors, dependent: :destroy
  acts_as_favoritable
end
