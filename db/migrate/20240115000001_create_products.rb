# frozen_string_literal: true

class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.text :description
      t.string :status, default: 'draft'
      t.references :category, foreign_key: true
      t.string :brand
      t.string :material
      t.decimal :weight, precision: 10, scale: 2
      t.string :shopify_product_id
      t.string :quickbooks_item_id
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :status
    add_index :products, :shopify_product_id
  end
end
