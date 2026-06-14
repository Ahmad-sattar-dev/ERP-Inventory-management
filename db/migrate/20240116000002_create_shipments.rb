# frozen_string_literal: true

class CreateShipments < ActiveRecord::Migration[7.1]
  def change
    create_table :shipments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :tracking_number, null: false
      t.string :carrier
      t.string :status, default: "pending"
      t.string :label_url
      t.decimal :cost, precision: 10, scale: 2
      t.datetime :shipped_at

      t.timestamps
    end

    add_index :shipments, :tracking_number
  end
end
