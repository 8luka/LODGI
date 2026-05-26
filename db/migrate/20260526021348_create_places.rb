class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places do |t|
      t.string :name
      t.string :category
      t.float :latitude
      t.float :longitude
      t.text :description

      t.timestamps
    end
  end
end
