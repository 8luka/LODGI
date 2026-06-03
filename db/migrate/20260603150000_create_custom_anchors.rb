class CreateCustomAnchors < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_anchors do |t|
      t.float :latitude
      t.float :longitude
      t.string :label
      t.timestamps
    end

    # Coords are rounded before insert (see InquiriesController#set_pinned_anchor), so the same
    # pinned spot reuses one row — and its cached TravelToAnchor times — instead of duplicating.
    add_index :custom_anchors, %i[latitude longitude], unique: true
  end
end
