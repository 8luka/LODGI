class Amenity < ApplicationRecord
  has_many :properties, through: :property_amenities
  has_many :property_amenities
end
