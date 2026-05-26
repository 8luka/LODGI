class Neighborhood < ApplicationRecord
  has_many :properties, dependent: :destroy
end
