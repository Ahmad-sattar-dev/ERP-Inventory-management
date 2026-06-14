# frozen_string_literal: true

class Location < ApplicationRecord
  has_many :inventory_items, dependent: :restrict_with_error

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
