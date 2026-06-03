# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_03_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "amenities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "custom_anchors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.float "latitude"
    t.float "longitude"
    t.datetime "updated_at", null: false
    t.index ["latitude", "longitude"], name: "index_custom_anchors_on_latitude_and_longitude", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.boolean "blocked", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "favoritable_id", null: false
    t.string "favoritable_type", null: false
    t.bigint "favoritor_id", null: false
    t.string "favoritor_type", null: false
    t.string "scope", default: "favorite", null: false
    t.datetime "updated_at", null: false
    t.index ["blocked"], name: "index_favorites_on_blocked"
    t.index ["favoritable_id", "favoritable_type"], name: "fk_favoritables"
    t.index ["favoritable_type", "favoritable_id", "favoritor_type", "favoritor_id", "scope"], name: "uniq_favorites__and_favoritables", unique: true
    t.index ["favoritable_type", "favoritable_id"], name: "index_favorites_on_favoritable"
    t.index ["favoritor_id", "favoritor_type"], name: "fk_favorites"
    t.index ["favoritor_type", "favoritor_id"], name: "index_favorites_on_favoritor"
    t.index ["scope"], name: "index_favorites_on_scope"
  end

  create_table "inquiries", force: :cascade do |t|
    t.bigint "anchor_id"
    t.string "anchor_type"
    t.date "check_in"
    t.date "check_out"
    t.float "commute_weight"
    t.datetime "created_at", null: false
    t.integer "guests"
    t.bigint "property_id"
    t.float "quiet_weight"
    t.text "selected_places", default: [], array: true
    t.float "station_weight"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "why_visit"
    t.index ["anchor_type", "anchor_id"], name: "index_inquiries_on_anchor"
    t.index ["property_id"], name: "index_inquiries_on_property_id"
    t.index ["user_id"], name: "index_inquiries_on_user_id"
  end

  create_table "neighborhoods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "features"
    t.boolean "is_landmark"
    t.boolean "is_workplace"
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.string "photos", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "ward"
  end

  create_table "places", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "distance_meters"
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.bigint "neighborhood_id"
    t.string "photos", default: [], array: true
    t.string "place_id"
    t.bigint "property_id"
    t.float "rating"
    t.datetime "updated_at", null: false
    t.index ["neighborhood_id"], name: "index_places_on_neighborhood_id"
    t.index ["place_id"], name: "index_places_on_place_id"
    t.index ["property_id", "category"], name: "index_places_on_property_id_and_category"
  end

  create_table "properties", force: :cascade do |t|
    t.string "all_amenities", default: [], array: true
    t.string "availability"
    t.integer "bedrooms"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "features", default: [], array: true
    t.integer "floors"
    t.string "images", default: [], array: true
    t.float "latitude"
    t.string "layout"
    t.float "longitude"
    t.string "matterport_url"
    t.string "name"
    t.bigint "neighborhood_id", null: false
    t.decimal "price", precision: 10, scale: 2
    t.text "rules"
    t.jsonb "score_inputs", default: {}, null: false
    t.float "size"
    t.string "stations", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.string "vendor_image"
    t.index ["neighborhood_id"], name: "index_properties_on_neighborhood_id"
  end

  create_table "property_amenities", force: :cascade do |t|
    t.bigint "amenity_id", null: false
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["amenity_id"], name: "index_property_amenities_on_amenity_id"
    t.index ["property_id"], name: "index_property_amenities_on_property_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.float "rating"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["property_id"], name: "index_reviews_on_property_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "travel_to_anchors", force: :cascade do |t|
    t.bigint "anchor_id", null: false
    t.string "anchor_type", null: false
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.integer "travel_time"
    t.datetime "updated_at", null: false
    t.index ["anchor_type", "anchor_id", "property_id"], name: "idx_travel_to_anchors_unique", unique: true
    t.index ["anchor_type", "anchor_id"], name: "index_travel_to_anchors_on_anchor"
    t.index ["property_id"], name: "index_travel_to_anchors_on_property_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workplaces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.bigint "neighborhood_id", null: false
    t.datetime "updated_at", null: false
    t.index ["neighborhood_id"], name: "index_workplaces_on_neighborhood_id"
  end

  add_foreign_key "inquiries", "properties"
  add_foreign_key "inquiries", "users"
  add_foreign_key "places", "neighborhoods"
  add_foreign_key "places", "properties"
  add_foreign_key "properties", "neighborhoods"
  add_foreign_key "property_amenities", "amenities"
  add_foreign_key "property_amenities", "properties"
  add_foreign_key "reviews", "properties"
  add_foreign_key "reviews", "users"
  add_foreign_key "travel_to_anchors", "properties"
  add_foreign_key "workplaces", "neighborhoods"
end
