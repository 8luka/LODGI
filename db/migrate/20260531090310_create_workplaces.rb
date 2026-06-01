class CreateWorkplaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workplaces do |t|
      t.string :name
      t.float :latitude
      t.float :longitude
      t.references :neighborhood, null: false, foreign_key: true

      t.timestamps
    end
  end
end
