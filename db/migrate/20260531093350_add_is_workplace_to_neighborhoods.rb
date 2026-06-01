class AddIsWorkplaceToNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    add_column :neighborhoods, :is_workplace, :boolean
  end
end
