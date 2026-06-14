# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.string :status, default: "pending"
      t.string :payment_method
      t.string :reference

      t.timestamps
    end

    add_index :payments, :status
  end
end
