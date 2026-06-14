# frozen_string_literal: true

class CreateOrderNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :order_notes do |t|
      t.references :order, null: false, foreign_key: true
      t.text :body, null: false
      t.string :author

      t.timestamps
    end
  end
end
