class Neighborhood < ApplicationRecord
  has_many :properties
  has_many :places
  has_many :workplaces
  has_many :inquiries, as: :anchor
end
