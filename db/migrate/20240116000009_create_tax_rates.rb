# frozen_string_literal: true

class CreateTaxRates < ActiveRecord::Migration[7.1]
  def change
    create_table :tax_rates do |t|
      t.string :state, null: false
      t.decimal :rate, precision: 6, scale: 4, null: false, default: 0

      t.timestamps
    end

    add_index :tax_rates, :state, unique: true
  end
end
