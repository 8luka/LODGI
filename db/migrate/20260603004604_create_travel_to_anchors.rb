class CreateTravelToAnchors < ActiveRecord::Migration[8.1]
  def change
    create_table :travel_to_anchors do |t|
      t.references :anchor, polymorphic: true, null: false   # which_anchor (Place | Neighborhood)
      t.references :property, null: false, foreign_key: true # which_property
      t.integer :travel_time                                 # transit minutes; nil = no route found
      t.timestamps
    end

    # One row per (anchor, property) — enforces dedupe and speeds the "which are missing?" lookup.
    add_index :travel_to_anchors, %i[anchor_type anchor_id property_id],
              unique: true, name: "idx_travel_to_anchors_unique"
  end
end
