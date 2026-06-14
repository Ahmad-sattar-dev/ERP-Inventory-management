# frozen_string_literal: true

# Idempotent seed data so a fresh database is immediately usable/demoable.
# Run with: bin/rails db:seed  (also runs automatically via db:prepare on boot)

puts "Seeding database..."

# --- API key (used for Bearer auth on /api/v1/* endpoints) ----------------
api_key = ApiKey.find_or_create_by!(name: "Default Development Key") do |k|
  k.token = ENV.fetch("SEED_API_TOKEN", "dev-token-please-change-me")
  k.active = true
end
puts "API key: #{api_key.token}"

# --- Tax rates ------------------------------------------------------------
{ "CA" => 0.0725, "NY" => 0.04, "TX" => 0.0625, "WA" => 0.065 }.each do |state, rate|
  TaxRate.find_or_create_by!(state: state) { |t| t.rate = rate }
end

# --- Locations ------------------------------------------------------------
warehouse = Location.find_or_create_by!(name: "Main Warehouse") do |l|
  l.code = "WH1"
  l.active = true
  l.city = "Los Angeles"
  l.state = "CA"
  l.country = "US"
end

# --- Price lists ----------------------------------------------------------
wholesale_list = PriceList.find_or_create_by!(name: "Wholesale") { |p| p.discount_rate = 15 }

# --- Categories -----------------------------------------------------------
tops = Category.find_or_create_by!(name: "Tops")
bottoms = Category.find_or_create_by!(name: "Bottoms")

# --- Products + variants + inventory --------------------------------------
product_data = [
  { name: "Classic Tee",   sku: "TEE-001",  category: tops,    price: 24.99, sizes: %w[S M L], colors: %w[Black White] },
  { name: "Denim Jeans",   sku: "JEAN-001", category: bottoms, price: 59.99, sizes: %w[30 32 34], colors: %w[Blue] }
]

product_data.each do |data|
  product = Product.find_or_create_by!(sku: data[:sku]) do |p|
    p.name = data[:name]
    p.status = "active"
    p.category = data[:category]
    p.brand = "DemoBrand"
  end

  data[:sizes].product(data[:colors]).each do |size, color|
    variant = ProductVariant.find_or_create_by!(
      product: product, size: size, color: color
    ) do |v|
      v.sku = "#{data[:sku]}-#{size}-#{color}".upcase
      v.price = data[:price]
      v.cost_price = (data[:price] * 0.4).round(2)
      v.active = true
    end

    InventoryItem.find_or_create_by!(product_variant: variant, location: warehouse) do |i|
      i.quantity = 100
      i.reorder_point = 10
      i.reorder_quantity = 50
      i.status = "available"
    end
  end
end

# --- Customer + address ---------------------------------------------------
customer = Customer.find_or_create_by!(email: "demo@example.com") do |c|
  c.first_name = "Demo"
  c.last_name = "Customer"
  c.customer_type = "retail"
  c.active = true
end

Address.find_or_create_by!(customer: customer, address_line_1: "123 Market St") do |a|
  a.city = "San Francisco"
  a.state = "CA"
  a.postal_code = "94103"
  a.country = "US"
end

puts "Seeding complete."
puts "  Products:   #{Product.count}"
puts "  Variants:   #{ProductVariant.count}"
puts "  Inventory:  #{InventoryItem.count}"
puts "  Customers:  #{Customer.count}"
