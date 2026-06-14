# frozen_string_literal: true

class CreateIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :integrations do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.text :credentials
      t.jsonb :settings, default: {}
      t.boolean :active, default: false
      t.boolean :sync_products, default: true
      t.boolean :sync_orders, default: true
      t.boolean :sync_customers, default: true
      t.boolean :sync_inventory, default: true
      t.datetime :last_sync_at
      t.datetime :last_sync_started_at
      t.string :sync_status
      t.text :last_error
      t.datetime :last_error_at

      t.timestamps
    end

    add_index :integrations, :provider, unique: true
  end
end
