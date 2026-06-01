class AddIsLandmarkToNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    add_column :neighborhoods, :is_landmark, :boolean
  end
end
