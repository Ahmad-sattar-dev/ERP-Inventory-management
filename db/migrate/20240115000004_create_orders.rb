# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.string :order_number, null: false
      t.references :customer, null: false, foreign_key: true
      t.string :status, default: 'draft'
      t.string :channel, default: 'manual'
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :shipping_amount, precision: 10, scale: 2, default: 0
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.string :currency, default: 'USD'
      t.references :shipping_address, foreign_key: { to_table: :addresses }
      t.references :billing_address, foreign_key: { to_table: :addresses }
      t.text :notes
      t.string :shopify_order_id
      t.string :quickbooks_invoice_id
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :status
    add_index :orders, :channel
    add_index :orders, :shopify_order_id
    add_index :orders, :created_at
  end
end
