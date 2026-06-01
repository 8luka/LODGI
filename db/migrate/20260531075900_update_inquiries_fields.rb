class UpdateInquiriesFields < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiries, :guests, :integer
    add_column :inquiries, :why_visit, :string
    add_column :inquiries, :anchor, :string
    add_reference :inquiries, :anchor, polymorphic: true, null: false

    remove_column :inquiries, :content, :text
  end
end
