class AddPhotosToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_column :places, :photos, :string, array: true, default: []
  end
end
