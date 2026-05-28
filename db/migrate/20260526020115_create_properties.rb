class CreateProperties < ActiveRecord::Migration[7.0]
  def change
    create_table :properties do |t|
      t.string   :name
      t.references   :neighborhood, null: false, foreign_key: true
      t.float  :latitude
      t.float  :longitude
      t.decimal  :price, precision: 10, scale: 2
      t.string   :layout
      t.integer  :bedrooms
      t.float  :size
      t.integer  :floors
      t.text     :description
      t.text     :rules
      t.string   :vendor
      t.string   :vendor_image
      t.string    :features, array: true, default: []
      t.string    :all_amenities, array: true, default: []
      t.string   :matterport_url
      t.string    :images, array: true, default: []

      t.timestamps
    end
  end
end
