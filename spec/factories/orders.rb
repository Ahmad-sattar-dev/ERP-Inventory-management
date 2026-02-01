# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :customer
    order_number { "ORD-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}" }
    status { 'draft' }
    channel { 'manual' }
    subtotal { 0 }
    tax_amount { 0 }
    shipping_amount { 0 }
    discount_amount { 0 }
    total { 0 }
    currency { 'USD' }

    trait :with_line_items do
      after(:create) do |order|
        create_list(:line_item, 2, order: order)
        order.calculate_totals
        order.save!
      end
    end

    trait :pending do
      status { 'pending' }
    end

    trait :confirmed do
      status { 'confirmed' }
    end

    trait :shipped do
      status { 'shipped' }
    end
  end

  factory :line_item do
    association :order
    association :product_variant
    quantity { 1 }
    unit_price { 29.99 }
  end

  factory :customer do
    email { Faker::Internet.unique.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    customer_type { 'retail' }
    active { true }
  end

  factory :product do
    name { Faker::Commerce.product_name }
    sku { "PRD-#{SecureRandom.hex(4).upcase}" }
    description { Faker::Lorem.paragraph }
    status { 'active' }
  end

  factory :product_variant do
    association :product
    sku { "VAR-#{SecureRandom.hex(4).upcase}" }
    size { %w[S M L XL].sample }
    color { Faker::Color.color_name }
    price { Faker::Commerce.price(range: 10..100) }
    cost_price { price * 0.5 }
    active { true }

    trait :with_stock do
      after(:create) do |variant|
        create(:inventory_item, product_variant: variant, quantity: 100)
      end
    end
  end

  factory :inventory_item do
    association :product_variant
    association :location
    quantity { 50 }
    reserved_quantity { 0 }
    reorder_point { 10 }
    reorder_quantity { 50 }
    status { 'available' }
  end

  factory :location do
    name { "Warehouse #{SecureRandom.hex(2).upcase}" }
    address { Faker::Address.full_address }
    active { true }
  end

  factory :integration do
    name { 'Test Integration' }
    provider { 'shopify' }
    credentials { {} }
    active { true }
  end

  factory :api_key do
    token { SecureRandom.hex(32) }
    name { 'Test API Key' }
    active { true }
  end

  factory :payment do
    association :order
    amount { 100.00 }
    status { 'completed' }
    payment_method { 'credit_card' }
  end

  factory :address do
    address_line_1 { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    postal_code { Faker::Address.zip_code }
    country { 'US' }
  end
end
