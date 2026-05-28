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

ActiveRecord::Schema[8.1].define(version: 2026_05_28_030632) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "amenities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "inquiries", force: :cascade do |t|
    t.date "check_in"
    t.date "check_out"
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["property_id"], name: "index_inquiries_on_property_id"
    t.index ["user_id"], name: "index_inquiries_on_user_id"
  end

  create_table "neighborhoods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "features"
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "ward"
  end

  create_table "places", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "properties", force: :cascade do |t|
    t.string "address"
    t.string "agency"
    t.date "available_from"
    t.date "available_until"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "guests"
    t.float "latitude"
    t.string "layout"
    t.float "longitude"
    t.string "name"
    t.bigint "neighborhood_id", null: false
    t.float "price"
    t.string "property_type"
    t.float "rating"
    t.string "rules"
    t.float "size"
    t.string "stations", default: [], array: true
    t.datetime "updated_at", null: false
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

  add_foreign_key "inquiries", "properties"
  add_foreign_key "inquiries", "users"
  add_foreign_key "properties", "neighborhoods"
  add_foreign_key "property_amenities", "amenities"
  add_foreign_key "property_amenities", "properties"
  add_foreign_key "reviews", "properties"
  add_foreign_key "reviews", "users"
end
