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

ActiveRecord::Schema.define(version: 2021_06_12_120547) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "carts", force: :cascade do |t|
    t.integer "telegram_id"
    t.string "telegram_username"
    t.string "contacts"
    t.boolean "completed", default: false
    t.jsonb "items", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer "user_age"
    t.string "instagram"
    t.string "full_name"
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_carts_on_deleted_at"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "ticket_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "approved"
    t.index ["user_id"], name: "index_ticket_requests_on_user_id"
  end

  create_table "transfer_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.string "route_to"
    t.string "route_return"
    t.boolean "approved"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_transfer_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "telegram_id"
    t.string "telegram_username"
    t.string "instagram"
    t.string "first_name"
    t.string "last_name"
    t.string "contacts"
    t.integer "age"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "carts", "users"
end
