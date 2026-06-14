# frozen_string_literal: true

class CreatePurchaseOrderLineItems < ActiveRecord::Migration[7.1]
  def change
    create_table :purchase_order_line_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_cost, precision: 10, scale: 2

      t.timestamps
    end
  end
end
