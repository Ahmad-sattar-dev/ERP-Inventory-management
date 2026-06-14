# frozen_string_literal: true

class CreateApiKeys < ActiveRecord::Migration[7.1]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.boolean :active, default: true
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_keys, :token, unique: true
  end
end
