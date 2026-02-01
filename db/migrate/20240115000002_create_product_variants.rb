# frozen_string_literal: true

class CreateProductVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :size
      t.string :color
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :cost_price, precision: 10, scale: 2
      t.decimal :compare_at_price, precision: 10, scale: 2
      t.string :barcode
      t.decimal :weight, precision: 10, scale: 2
      t.boolean :active, default: true
      t.string :shopify_variant_id
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :product_variants, :sku, unique: true
    add_index :product_variants, :shopify_variant_id
    add_index :product_variants, [:product_id, :size, :color]
  end
end
