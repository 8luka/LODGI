class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.string :name
      t.references :neighborhood, null: false, foreign_key: true
      t.string :address
      t.float :price
      t.text :description
      t.string :agency
      t.float :rating
      t.string :layout
      t.integer :guests
      t.float :size
      t.string :rules
      t.string :property_type
      t.date :available_from
      t.date :available_until
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
