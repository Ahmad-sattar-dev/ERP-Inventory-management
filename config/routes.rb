# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Products
      resources :products do
        member do
          get :inventory
          post :sync
        end
      end

      # Orders
      resources :orders do
        member do
          post :confirm
          post :ship
          post :cancel
        end
      end

      # Inventory
      resources :inventory, only: [:index, :show, :update] do
        member do
          post :adjust
        end
        collection do
          post :bulk_adjust
          get :low_stock
          get :summary
          post :transfer
        end
      end

      # Customers
      resources :customers

      # Webhooks
      namespace :webhooks do
        post :shopify
        post :quickbooks
        post :shipstation
      end
    end
  end

  # Health check
  get '/health', to: proc { [200, {}, ['OK']] }
end
