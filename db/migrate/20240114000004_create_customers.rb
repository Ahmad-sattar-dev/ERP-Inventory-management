# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.string :company_name
      t.string :phone
      t.string :customer_type, default: "retail"
      t.boolean :tax_exempt, default: false
      t.string :tax_id
      t.decimal :credit_limit, precision: 10, scale: 2, default: 0
      t.integer :payment_terms, default: 0
      t.references :price_list, foreign_key: true
      # FKs to addresses are omitted here because the addresses table is created
      # afterwards (customers <-> addresses is circular). Plain bigint columns.
      t.bigint :default_shipping_address_id
      t.bigint :default_billing_address_id
      t.string :shopify_customer_id
      t.string :quickbooks_customer_id
      t.boolean :active, default: true
      t.text :notes
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :customers, :email, unique: true
    add_index :customers, :customer_type
    add_index :customers, :shopify_customer_id
  end
end
