class Place < ApplicationRecord
  belongs_to :neighborhood, optional: true
  belongs_to :property, optional: true
  has_many :inquiries, as: :anchor
  acts_as_favoritable
end
