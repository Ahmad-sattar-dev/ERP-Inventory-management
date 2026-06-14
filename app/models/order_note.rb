# frozen_string_literal: true

class OrderNote < ApplicationRecord
  belongs_to :order

  validates :body, presence: true
end
