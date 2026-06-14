# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :order
  belongs_to :product_variant

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_unit_price_from_variant, on: :create, if: -> { unit_price.blank? }

  def total
    quantity * unit_price
  end

  private

  def set_unit_price_from_variant
    self.unit_price = product_variant&.price
  end
end
