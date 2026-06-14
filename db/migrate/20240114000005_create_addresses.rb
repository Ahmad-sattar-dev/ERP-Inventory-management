# frozen_string_literal: true

class CreateAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :addresses do |t|
      t.references :customer, foreign_key: true
      t.string :label
      t.string :address_line_1, null: false
      t.string :address_line_2
      t.string :city, null: false
      t.string :state
      t.string :postal_code
      t.string :country, null: false, default: "US"

      t.timestamps
    end
  end
end
