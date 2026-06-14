# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_01_16_000011) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "label"
    t.string "address_line_1", null: false
    t.string "address_line_2"
    t.string "city", null: false
    t.string "state"
    t.string "postal_code"
    t.string "country", default: "US", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_addresses_on_customer_id"
  end

  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "token", null: false
    t.boolean "active", default: true
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_api_keys_on_token", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name"
  end

  create_table "customers", force: :cascade do |t|
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "company_name"
    t.string "phone"
    t.string "customer_type", default: "retail"
    t.boolean "tax_exempt", default: false
    t.string "tax_id"
    t.decimal "credit_limit", precision: 10, scale: 2, default: "0.0"
    t.integer "payment_terms", default: 0
    t.bigint "price_list_id"
    t.bigint "default_shipping_address_id"
    t.bigint "default_billing_address_id"
    t.string "shopify_customer_id"
    t.string "quickbooks_customer_id"
    t.boolean "active", default: true
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["email"], name: "index_customers_on_email", unique: true
    t.index ["price_list_id"], name: "index_customers_on_price_list_id"
    t.index ["shopify_customer_id"], name: "index_customers_on_shopify_customer_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider", null: false
    t.text "credentials"
    t.jsonb "settings", default: {}
    t.boolean "active", default: false
    t.boolean "sync_products", default: true
    t.boolean "sync_orders", default: true
    t.boolean "sync_customers", default: true
    t.boolean "sync_inventory", default: true
    t.datetime "last_sync_at"
    t.datetime "last_sync_started_at"
    t.string "sync_status"
    t.text "last_error"
    t.datetime "last_error_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider"], name: "index_integrations_on_provider", unique: true
  end

  create_table "inventory_items", force: :cascade do |t|
    t.bigint "product_variant_id", null: false
    t.bigint "location_id", null: false
    t.integer "quantity", default: 0, null: false
    t.integer "reserved_quantity", default: 0
    t.integer "reorder_point"
    t.integer "reorder_quantity"
    t.string "status", default: "available"
    t.string "bin_location"
    t.datetime "last_counted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_inventory_items_on_location_id"
    t.index ["product_variant_id", "location_id"], name: "index_inventory_items_on_product_variant_id_and_location_id", unique: true
    t.index ["product_variant_id"], name: "index_inventory_items_on_product_variant_id"
    t.index ["quantity"], name: "index_inventory_items_on_quantity"
    t.index ["status"], name: "index_inventory_items_on_status"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.bigint "inventory_item_id", null: false
    t.integer "quantity_change", null: false
    t.string "reason"
    t.string "reference_type"
    t.bigint "reference_id"
    t.integer "resulting_quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_item_id"], name: "index_inventory_movements_on_inventory_item_id"
    t.index ["reference_type", "reference_id"], name: "index_inventory_movements_on_reference_type_and_reference_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["product_variant_id"], name: "index_line_items_on_product_variant_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.string "shopify_location_id"
    t.boolean "active", default: true
    t.string "address_line_1"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_locations_on_code", unique: true, where: "(code IS NOT NULL)"
  end

  create_table "order_notes", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.text "body", null: false
    t.string "author"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_notes_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_number", null: false
    t.bigint "customer_id", null: false
    t.string "status", default: "draft"
    t.string "channel", default: "manual"
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "shipping_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.string "currency", default: "USD"
    t.bigint "shipping_address_id"
    t.bigint "billing_address_id"
    t.text "notes"
    t.string "shopify_order_id"
    t.string "quickbooks_invoice_id"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billing_address_id"], name: "index_orders_on_billing_address_id"
    t.index ["channel"], name: "index_orders_on_channel"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["shipping_address_id"], name: "index_orders_on_shipping_address_id"
    t.index ["shopify_order_id"], name: "index_orders_on_shopify_order_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "status", default: "pending"
    t.string "payment_method"
    t.string "reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["status"], name: "index_payments_on_status"
  end

  create_table "price_lists", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "discount_rate", precision: 5, scale: 2, default: "0.0"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku", null: false
    t.string "size"
    t.string "color"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "cost_price", precision: 10, scale: 2
    t.decimal "compare_at_price", precision: 10, scale: 2
    t.string "barcode"
    t.decimal "weight", precision: 10, scale: 2
    t.boolean "active", default: true
    t.string "shopify_variant_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "size", "color"], name: "index_product_variants_on_product_id_and_size_and_color"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["shopify_variant_id"], name: "index_product_variants_on_shopify_variant_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "sku", null: false
    t.text "description"
    t.string "status", default: "draft"
    t.bigint "category_id"
    t.string "brand"
    t.string "material"
    t.decimal "weight", precision: 10, scale: 2
    t.string "shopify_product_id"
    t.string "quickbooks_item_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["shopify_product_id"], name: "index_products_on_shopify_product_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["status"], name: "index_products_on_status"
  end

  create_table "purchase_order_line_items", force: :cascade do |t|
    t.bigint "purchase_order_id", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "unit_cost", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_purchase_order_line_items_on_product_variant_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_line_items_on_purchase_order_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.string "status", default: "draft"
    t.string "supplier_name"
    t.datetime "expected_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_purchase_orders_on_status"
  end

  create_table "shipments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "tracking_number", null: false
    t.string "carrier"
    t.string "status", default: "pending"
    t.string "label_url"
    t.decimal "cost", precision: 10, scale: 2
    t.datetime "shipped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipments_on_order_id"
    t.index ["tracking_number"], name: "index_shipments_on_tracking_number"
  end

  create_table "stock_reservations", force: :cascade do |t|
    t.bigint "inventory_item_id", null: false
    t.bigint "order_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_stock_reservations_on_expires_at"
    t.index ["inventory_item_id"], name: "index_stock_reservations_on_inventory_item_id"
    t.index ["order_id"], name: "index_stock_reservations_on_order_id"
  end

  create_table "tax_rates", force: :cascade do |t|
    t.string "state", null: false
    t.decimal "rate", precision: 6, scale: 4, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state"], name: "index_tax_rates_on_state", unique: true
  end

  add_foreign_key "addresses", "customers"
  add_foreign_key "customers", "price_lists"
  add_foreign_key "inventory_items", "locations"
  add_foreign_key "inventory_items", "product_variants"
  add_foreign_key "inventory_movements", "inventory_items"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "product_variants"
  add_foreign_key "order_notes", "orders"
  add_foreign_key "orders", "addresses", column: "billing_address_id"
  add_foreign_key "orders", "addresses", column: "shipping_address_id"
  add_foreign_key "orders", "customers"
  add_foreign_key "payments", "orders"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "purchase_order_line_items", "product_variants"
  add_foreign_key "purchase_order_line_items", "purchase_orders"
  add_foreign_key "shipments", "orders"
  add_foreign_key "stock_reservations", "inventory_items"
  add_foreign_key "stock_reservations", "orders"
end
