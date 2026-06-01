class MakeNeighborhoodOptionalOnPlaces < ActiveRecord::Migration[8.1]
  def change
    change_column_null :places, :neighborhood_id, true
  end
end
