# frozen_string_literal: true

class Shipment < ApplicationRecord
  belongs_to :order

  validates :tracking_number, presence: true

  scope :in_transit, -> { where(status: "in_transit") }
end
