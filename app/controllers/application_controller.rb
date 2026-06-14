# frozen_string_literal: true

# Base controller for the API. Individual API controllers inherit from
# Api::V1::BaseController, but this exists so Rails has a conventional root.
class ApplicationController < ActionController::API
end
