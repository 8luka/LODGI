class AddGoogleFieldsToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_column :places, :place_id, :string
    add_column :places, :rating, :float

    add_index :places,
              :place_id,
              unique: true
  end
end
