class RemoveAnchorFromInquiries < ActiveRecord::Migration[8.1]
  def change
    remove_column :inquiries, :anchor, :string
  end
end
