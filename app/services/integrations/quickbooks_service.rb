# frozen_string_literal: true

module Integrations
  class QuickbooksService < BaseService
    BASE_URL = "https://quickbooks.api.intuit.com/v3/company"

    def initialize(integration = nil)
      super
      setup_client if integration&.configured?
    end

    def test_connection
      response = get("companyinfo/#{realm_id}")
      response['CompanyInfo'].present?
    rescue StandardError => e
      log_error("Connection test failed", e)
      false
    end

    def full_sync
      sync_customers if integration.sync_customers?
      sync_invoices if integration.sync_orders?
    end

    # Customer Operations
    def sync_customers
      log_info("Starting customer sync from QuickBooks")

      customers = query("SELECT * FROM Customer MAXRESULTS 1000")
      customers['Customer']&.each do |qb_customer|
        sync_customer_from_quickbooks(qb_customer)
      end
    end

    def create_customer(customer)
      payload = build_customer_payload(customer)
      response = post("customer", payload)

      customer.update!(quickbooks_customer_id: response['Customer']['Id'])
      log_info("Created QuickBooks customer: #{response['Customer']['Id']}")

      response['Customer']
    end

    def update_customer(customer)
      qb_customer = get("customer/#{customer.quickbooks_customer_id}")

      payload = build_customer_payload(customer)
      payload['Id'] = customer.quickbooks_customer_id
      payload['SyncToken'] = qb_customer['Customer']['SyncToken']

      post("customer", payload)
    end

    def sync_customer(customer)
      if customer.quickbooks_customer_id.present?
        update_customer(customer)
      else
        create_customer(customer)
      end
    end

    # Invoice Operations
    def create_invoice(order)
      ensure_customer_exists(order.customer)

      payload = build_invoice_payload(order)
      response = post("invoice", payload)

      order.update!(quickbooks_invoice_id: response['Invoice']['Id'])
      log_info("Created QuickBooks invoice: #{response['Invoice']['Id']}")

      response['Invoice']
    end

    def update_invoice(order)
      qb_invoice = get("invoice/#{order.quickbooks_invoice_id}")

      payload = build_invoice_payload(order)
      payload['Id'] = order.quickbooks_invoice_id
      payload['SyncToken'] = qb_invoice['Invoice']['SyncToken']

      post("invoice", payload)
    end

    def void_invoice(order)
      return unless order.quickbooks_invoice_id.present?

      qb_invoice = get("invoice/#{order.quickbooks_invoice_id}")

      post("invoice?operation=void", {
        'Id' => order.quickbooks_invoice_id,
        'SyncToken' => qb_invoice['Invoice']['SyncToken']
      })
    end

    def get_invoice_pdf(invoice_id)
      response = HTTParty.get(
        "#{BASE_URL}/#{realm_id}/invoice/#{invoice_id}/pdf",
        headers: auth_headers.merge('Accept' => 'application/pdf')
      )

      response.body
    end

    # Payment Operations
    def create_payment(order, amount:, payment_method: 'Credit Card')
      ensure_customer_exists(order.customer)

      payload = {
        'CustomerRef' => { 'value' => order.customer.quickbooks_customer_id },
        'TotalAmt' => amount,
        'Line' => [{
          'Amount' => amount,
          'LinkedTxn' => [{
            'TxnId' => order.quickbooks_invoice_id,
            'TxnType' => 'Invoice'
          }]
        }],
        'PaymentMethodRef' => { 'name' => payment_method }
      }

      response = post("payment", payload)
      log_info("Created QuickBooks payment: #{response['Payment']['Id']}")

      response['Payment']
    end

    # Product/Item Operations
    def create_item(product)
      payload = build_item_payload(product)
      response = post("item", payload)

      product.update!(quickbooks_item_id: response['Item']['Id'])
      response['Item']
    end

    def update_item(product)
      qb_item = get("item/#{product.quickbooks_item_id}")

      payload = build_item_payload(product)
      payload['Id'] = product.quickbooks_item_id
      payload['SyncToken'] = qb_item['Item']['SyncToken']

      post("item", payload)
    end

    # Token Management
    def refresh_token
      response = HTTParty.post(
        'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
        headers: {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Authorization' => "Basic #{Base64.strict_encode64("#{credentials[:client_id]}:#{credentials[:client_secret]}")}"
        },
        body: {
          grant_type: 'refresh_token',
          refresh_token: credentials[:refresh_token]
        }
      )

      if response.code == 200
        {
          'access_token' => response['access_token'],
          'refresh_token' => response['refresh_token'],
          'expires_at' => Time.current + response['expires_in'].to_i.seconds
        }
      else
        raise AuthenticationError, "Failed to refresh token: #{response.body}"
      end
    end

    private

    def setup_client
      @access_token = credentials[:access_token]
      @realm_id = credentials[:realm_id]
    end

    def realm_id
      @realm_id
    end

    def auth_headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    end

    def get(endpoint)
      with_retry do
        response = HTTParty.get(
          "#{BASE_URL}/#{realm_id}/#{endpoint}",
          headers: auth_headers
        )
        handle_response(response)
      end
    end

    def post(endpoint, body)
      with_retry do
        response = HTTParty.post(
          "#{BASE_URL}/#{realm_id}/#{endpoint}",
          headers: auth_headers,
          body: body.to_json
        )
        handle_response(response)
      end
    end

    def query(sql)
      with_retry do
        response = HTTParty.get(
          "#{BASE_URL}/#{realm_id}/query",
          headers: auth_headers,
          query: { query: sql }
        )
        handle_response(response)['QueryResponse']
      end
    end

    def handle_response(response)
      case response.code
      when 200..299
        response.parsed_response
      when 401
        # Try to refresh token and retry
        integration.refresh_oauth_token!
        @access_token = integration.credentials['access_token']
        raise RetryableError, "Token refreshed, retry request"
      when 429
        raise RateLimitError, "Rate limited by QuickBooks"
      else
        error_message = response.parsed_response&.dig('Fault', 'Error')&.first&.dig('Message')
        raise ApiError, "QuickBooks API error: #{response.code} - #{error_message || response.body}"
      end
    end

    def ensure_customer_exists(customer)
      return if customer.quickbooks_customer_id.present?
      create_customer(customer)
    end

    def build_customer_payload(customer)
      {
        'DisplayName' => customer.display_name,
        'GivenName' => customer.first_name,
        'FamilyName' => customer.last_name,
        'CompanyName' => customer.company_name,
        'PrimaryEmailAddr' => { 'Address' => customer.email },
        'PrimaryPhone' => customer.phone.present? ? { 'FreeFormNumber' => customer.phone } : nil,
        'BillAddr' => customer.default_billing_address.present? ? build_address(customer.default_billing_address) : nil,
        'ShipAddr' => customer.default_shipping_address.present? ? build_address(customer.default_shipping_address) : nil
      }.compact
    end

    def build_address(address)
      {
        'Line1' => address.address_line_1,
        'Line2' => address.address_line_2,
        'City' => address.city,
        'CountrySubDivisionCode' => address.state,
        'PostalCode' => address.postal_code,
        'Country' => address.country
      }.compact
    end

    def build_invoice_payload(order)
      {
        'CustomerRef' => { 'value' => order.customer.quickbooks_customer_id },
        'DocNumber' => order.order_number,
        'TxnDate' => order.created_at.to_date.iso8601,
        'DueDate' => (order.created_at + order.customer.payment_terms.days).to_date.iso8601,
        'Line' => build_invoice_lines(order),
        'ShipAddr' => order.shipping_address.present? ? build_address(order.shipping_address) : nil,
        'BillAddr' => order.billing_address.present? ? build_address(order.billing_address) : nil
      }.compact
    end

    def build_invoice_lines(order)
      lines = order.line_items.map do |line_item|
        ensure_item_exists(line_item.product_variant.product)

        {
          'DetailType' => 'SalesItemLineDetail',
          'Amount' => (line_item.quantity * line_item.unit_price).to_f,
          'SalesItemLineDetail' => {
            'ItemRef' => { 'value' => line_item.product_variant.product.quickbooks_item_id },
            'Qty' => line_item.quantity,
            'UnitPrice' => line_item.unit_price.to_f
          }
        }
      end

      # Add shipping line if applicable
      if order.shipping_amount.to_f > 0
        lines << {
          'DetailType' => 'SalesItemLineDetail',
          'Amount' => order.shipping_amount.to_f,
          'Description' => 'Shipping',
          'SalesItemLineDetail' => {
            'ItemRef' => { 'name' => 'Shipping' }
          }
        }
      end

      lines
    end

    def build_item_payload(product)
      {
        'Name' => product.name.truncate(100),
        'Sku' => product.sku,
        'Description' => product.description&.truncate(4000),
        'Type' => 'Inventory',
        'TrackQtyOnHand' => true,
        'QtyOnHand' => product.total_stock,
        'InvStartDate' => Date.current.iso8601,
        'IncomeAccountRef' => { 'name' => 'Sales of Product Income' },
        'ExpenseAccountRef' => { 'name' => 'Cost of Goods Sold' },
        'AssetAccountRef' => { 'name' => 'Inventory Asset' }
      }
    end

    def ensure_item_exists(product)
      return if product.quickbooks_item_id.present?
      create_item(product)
    end

    def sync_customer_from_quickbooks(qb_customer)
      customer = Customer.find_or_initialize_by(quickbooks_customer_id: qb_customer['Id'])

      customer.assign_attributes(
        email: qb_customer.dig('PrimaryEmailAddr', 'Address') || "qb-#{qb_customer['Id']}@placeholder.com",
        first_name: qb_customer['GivenName'],
        last_name: qb_customer['FamilyName'],
        company_name: qb_customer['CompanyName'],
        phone: qb_customer.dig('PrimaryPhone', 'FreeFormNumber')
      )

      customer.save!
      customer
    end
  end

  class RetryableError < StandardError; end
end
