class CreateNeighborhoods < ActiveRecord::Migration[8.1]
  def change
    create_table :neighborhoods do |t|
      t.string :name
      t.text :description
      t.text :features
      t.string :ward
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
