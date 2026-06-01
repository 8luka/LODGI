class Place < ApplicationRecord
  belongs_to :neighborhood, optional: true
  has_many :inquiries, as: :anchor
end
