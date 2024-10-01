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

ActiveRecord::Schema[7.2].define(version: 2024_09_28_235932) do
  create_table "super_settings", force: :cascade do |t|
    t.string "key", limit: 190, null: false
    t.string "value_type", limit: 30, default: "string", null: false
    t.string "raw_value", limit: 4096
    t.string "description", limit: 4096
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "created_at", precision: nil, null: false
    t.boolean "deleted", default: false
    t.index ["key"], name: "index_super_settings_on_key", unique: true
    t.index ["updated_at"], name: "index_super_settings_on_updated_at"
  end

  create_table "super_settings_histories", force: :cascade do |t|
    t.string "key", limit: 190, null: false
    t.string "changed_by", limit: 150
    t.string "value", limit: 4096
    t.boolean "deleted", default: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["changed_by"], name: "index_super_settings_histories_on_changed_by"
    t.index ["key"], name: "index_super_settings_histories_on_key"
  end
end
