class RelaxPlaceIdUniqueIndexOnPlaces < ActiveRecord::Migration[8.1]
  # The v2 amenity pipeline intentionally creates duplicate place_id rows
  # (the same amenity can be near multiple properties, and re-runs add more
  # rows by design). Drop the unique index and replace it with a plain one.
  # v1's find_or_create_by!/find_by checks still work in application code.
  def change
    remove_index :places, name: "index_places_on_place_id"
    add_index :places, :place_id
  end
end
