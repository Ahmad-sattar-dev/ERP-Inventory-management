# frozen_string_literal: true

class CreateStockReservations < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_reservations do |t|
      t.references :inventory_item, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 0
      t.datetime :expires_at

      t.timestamps
    end

    add_index :stock_reservations, :expires_at
  end
end
