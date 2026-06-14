# frozen_string_literal: true

require "securerandom"

# Bearer tokens used to authenticate API requests (see Api::V1::BaseController).
class ApiKey < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }

  before_validation :generate_token, on: :create, if: -> { token.blank? }

  private

  def generate_token
    self.token = SecureRandom.hex(24)
  end
end
