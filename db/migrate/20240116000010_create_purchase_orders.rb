# frozen_string_literal: true

class CreatePurchaseOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :purchase_orders do |t|
      t.string :status, default: "draft"
      t.string :supplier_name
      t.datetime :expected_at
      t.text :notes

      t.timestamps
    end

    add_index :purchase_orders, :status
  end
end
