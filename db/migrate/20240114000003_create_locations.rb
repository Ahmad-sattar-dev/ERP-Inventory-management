# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :code
      t.string :shopify_location_id
      t.boolean :active, default: true
      t.string :address_line_1
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country

      t.timestamps
    end

    add_index :locations, :code, unique: true, where: "code IS NOT NULL"
  end
end
