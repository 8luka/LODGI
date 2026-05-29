class AddPhotosToNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    add_column :neighborhoods, :photos, :string, array: true, default: []
  end
end
