class AddPropertyAndDistanceToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_reference :places, :property, foreign_key: true, null: true, index: false
    add_column :places, :distance_meters, :integer, null: true
    add_index :places, [:property_id, :category]
  end
end
