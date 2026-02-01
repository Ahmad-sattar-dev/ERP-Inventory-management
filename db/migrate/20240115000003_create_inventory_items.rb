# frozen_string_literal: true

class CreateInventoryItems < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_items do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :quantity, default: 0, null: false
      t.integer :reserved_quantity, default: 0
      t.integer :reorder_point
      t.integer :reorder_quantity
      t.string :status, default: 'available'
      t.string :bin_location
      t.datetime :last_counted_at

      t.timestamps
    end

    add_index :inventory_items, [:product_variant_id, :location_id], unique: true
    add_index :inventory_items, :status
    add_index :inventory_items, :quantity
  end
end
