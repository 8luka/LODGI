class AddNeighborhoodsToPlaces < ActiveRecord::Migration[8.1]
  def change
    add_reference :places, :neighborhood, null: false, foreign_key: true
  end
end
