# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :customer, optional: true

  validates :address_line_1, :city, :country, presence: true

  def full_address
    [address_line_1, address_line_2, city, state, postal_code, country].compact_blank.join(", ")
  end
end
