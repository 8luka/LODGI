class Inquiry < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :property, optional: true
  belongs_to :anchor, polymorphic: true, optional: true
end
