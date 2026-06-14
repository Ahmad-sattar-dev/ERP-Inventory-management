# frozen_string_literal: true

class CreateInventoryMovements < ActiveRecord::Migration[7.1]
  def change
    create_table :inventory_movements do |t|
      t.references :inventory_item, null: false, foreign_key: true
      t.integer :quantity_change, null: false
      t.string :reason
      t.string :reference_type
      t.bigint :reference_id
      t.integer :resulting_quantity

      t.timestamps
    end

    add_index :inventory_movements, [:reference_type, :reference_id]
  end
end
