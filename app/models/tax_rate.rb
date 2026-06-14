# frozen_string_literal: true

class TaxRate < ApplicationRecord
  validates :state, presence: true, uniqueness: true
  validates :rate, numericality: { greater_than_or_equal_to: 0 }

  # Returns the decimal tax rate for a US state code (e.g. 0.0725), or 0.
  def self.for_state(state)
    return 0 if state.blank?

    find_by(state: state)&.rate || 0
  end
end
