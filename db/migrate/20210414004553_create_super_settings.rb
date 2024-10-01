# frozen_string_literal: true

class CreateSuperSettings < ActiveRecord::Migration[5.0]
  def up
    create_table :super_settings do |t|
      t.string :key, null: false, limit: 190, index: {unique: true}
      t.string :value_type, limit: 30, null: false, default: "string"
      t.string :raw_value, limit: 4096, null: true
      t.string :description, limit: 4096, null: true
      t.datetime :updated_at, null: false, index: true
      t.datetime :created_at, null: false
      t.boolean :deleted, default: false
    end

    create_table :super_settings_histories do |t|
      t.string :key, null: false, limit: 190, index: true
      t.string :changed_by, limit: 150, null: true, index: true
      t.string :value, limit: 4096, null: true
      t.boolean :deleted, default: false
      t.datetime :created_at, null: false
    end
  end

  def down
    drop_table :super_settings
    drop_table :super_settings_histories
  end
end
