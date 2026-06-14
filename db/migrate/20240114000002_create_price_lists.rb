# frozen_string_literal: true

class CreatePriceLists < ActiveRecord::Migration[7.1]
  def change
    create_table :price_lists do |t|
      t.string :name, null: false
      t.decimal :discount_rate, precision: 5, scale: 2, default: 0
      t.text :description

      t.timestamps
    end
  end
end
