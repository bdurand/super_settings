# frozen_string_literal: true

class CreateSuperSettings < ActiveRecord::Migration[4.2]

  def up
    create_table :super_settings do |t|
      t.string :key, null: false, limit: 255, index: {unique: true}
      t.string :value_type, limit: 30, null: false, default: "string"
      t.string :raw_value, limit: 4096, null: true
      t.string :description, limit: 4096, null: true
      t.datetime :updated_at, null: false
      t.datetime :created_at, null: false
      t.datetime :deleted_at, null: true
    end
  end

  def down
    drop_table :super_settings
  end

end