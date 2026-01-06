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

ActiveRecord::Schema[8.0].define(version: 2026_01_06_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "brands", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "country"
    t.string "website_url"
    t.string "logo_url"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_brands_on_name"
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "display_name", null: false
    t.uuid "parent_id"
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "compatibilities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "equipment_a_id", null: false
    t.uuid "equipment_b_id", null: false
    t.integer "compatibility_score", null: false
    t.jsonb "compatibility_details", default: {}
    t.string "source", null: false
    t.string "source_url"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_a_id", "equipment_b_id"], name: "index_compatibilities_on_equipment_a_id_and_equipment_b_id", unique: true
    t.index ["equipment_a_id"], name: "index_compatibilities_on_equipment_a_id"
    t.index ["equipment_b_id"], name: "index_compatibilities_on_equipment_b_id"
  end

  create_table "equipment", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "category_id", null: false
    t.uuid "brand_id", null: false
    t.string "model", null: false
    t.string "slug", null: false
    t.integer "release_year"
    t.integer "msrp_jpy"
    t.string "status", default: "active"
    t.jsonb "specs", default: {}
    t.jsonb "images", default: []
    t.text "description"
    t.text "features", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id", "model"], name: "index_equipment_on_brand_id_and_model", unique: true
    t.index ["brand_id"], name: "index_equipment_on_brand_id"
    t.index ["category_id"], name: "index_equipment_on_category_id"
    t.index ["slug"], name: "index_equipment_on_slug", unique: true
    t.index ["specs"], name: "index_equipment_on_specs", using: :gin
    t.index ["status"], name: "index_equipment_on_status"
  end

  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "compatibilities", "equipment", column: "equipment_a_id"
  add_foreign_key "compatibilities", "equipment", column: "equipment_b_id"
  add_foreign_key "equipment", "brands"
  add_foreign_key "equipment", "categories"
end
