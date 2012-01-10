# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120103225834) do

  create_table "external_people", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "gender",            :limit => 16
    t.date     "birthday"
    t.integer  "age"
    t.string   "crypted_password",  :limit => 40
    t.string   "salt",              :limit => 40
    t.integer  "person_id",                                          :null => false
    t.boolean  "tos",                             :default => false
    t.datetime "email_verified_at"
    t.string   "zip"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "external_people", ["person_id"], :name => "index_external_people_on_person_id"

  create_table "facebook_people", :force => true do |t|
    t.integer  "person_id",                :null => false
    t.integer  "uid",                      :null => false
    t.datetime "last_fetched"
    t.string   "first_name"
    t.string   "last_name"
    t.integer  "birth_year"
    t.integer  "birth_day"
    t.integer  "birth_month"
    t.integer  "age"
    t.string   "gender"
    t.string   "friend_checksum"
    t.datetime "stream_publish_access_at"
    t.integer  "stream_publish_city_id"
    t.datetime "stream_publish_ok_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "facebook_people", ["person_id"], :name => "index_facebook_people_on_person_id"
  add_index "facebook_people", ["uid"], :name => "index_facebook_people_on_uid"

  create_table "people", :force => true do |t|
    t.integer  "origin_city_id"
    t.string   "ref"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "people", ["email"], :name => "index_people_on_email"

end
