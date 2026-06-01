class Workplace < ApplicationRecord
  belongs_to :neighborhood
  has_many :inquiries, as: :anchor
end
