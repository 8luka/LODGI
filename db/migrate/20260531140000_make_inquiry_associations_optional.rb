class MakeInquiryAssociationsOptional < ActiveRecord::Migration[7.1]
  def change
    change_column_null :inquiries, :user_id, true
    change_column_null :inquiries, :property_id, true
    change_column_null :inquiries, :anchor_id, true
    change_column_null :inquiries, :anchor_type, true
  end
end
