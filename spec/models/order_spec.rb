# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'associations' do
    it { should belong_to(:customer) }
    it { should belong_to(:shipping_address).class_name('Address').optional }
    it { should belong_to(:billing_address).class_name('Address').optional }
    it { should have_many(:line_items).dependent(:destroy) }
    it { should have_many(:product_variants).through(:line_items) }
    it { should have_many(:shipments).dependent(:destroy) }
    it { should have_many(:payments).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:order_number) }
    it { should validate_uniqueness_of(:order_number) }
    it { should validate_presence_of(:status) }
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates order number on create' do
        order = build(:order, order_number: nil)
        order.valid?
        expect(order.order_number).to match(/^ORD-\d{8}-[A-F0-9]{6}$/)
      end
    end

    describe 'before_save' do
      it 'calculates totals' do
        order = create(:order)
        line_item = create(:line_item, order: order, quantity: 2, unit_price: 50.00)

        order.reload
        expect(order.subtotal).to eq(100.00)
      end
    end
  end

  describe 'state machine' do
    let(:order) { create(:order, :with_line_items, status: 'draft') }

    describe '#submit' do
      it 'transitions from draft to pending' do
        expect { order.submit! }.to change { order.status }.from('draft').to('pending')
      end

      it 'reserves inventory' do
        expect(order).to receive(:reserve_inventory!)
        order.submit!
      end
    end

    describe '#confirm' do
      let(:order) { create(:order, :with_line_items, status: 'pending') }

      it 'transitions from pending to confirmed' do
        expect { order.confirm! }.to change { order.status }.from('pending').to('confirmed')
      end

      it 'notifies customer' do
        expect(OrderMailer).to receive(:order_confirmed).and_return(double(deliver_later: true))
        order.confirm!
      end
    end

    describe '#ship' do
      let(:order) { create(:order, :with_line_items, status: 'processing') }

      it 'transitions from processing to shipped' do
        expect { order.ship! }.to change { order.status }.from('processing').to('shipped')
      end
    end

    describe '#cancel' do
      let(:order) { create(:order, :with_line_items, status: 'pending') }

      it 'transitions to cancelled' do
        expect { order.cancel! }.to change { order.status }.from('pending').to('cancelled')
      end

      it 'releases inventory' do
        expect(order).to receive(:release_inventory!)
        order.cancel!
      end

      it 'cannot cancel a shipped order' do
        order.update!(status: 'shipped')
        expect { order.cancel! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe '#calculate_totals' do
    let(:order) { create(:order) }

    before do
      create(:line_item, order: order, quantity: 2, unit_price: 50.00)
      create(:line_item, order: order, quantity: 1, unit_price: 75.00)
      order.shipping_amount = 10.00
      order.discount_amount = 5.00
    end

    it 'calculates subtotal from line items' do
      order.calculate_totals
      expect(order.subtotal).to eq(175.00) # (2 * 50) + (1 * 75)
    end

    it 'calculates total including shipping and discount' do
      order.calculate_totals
      expect(order.total).to eq(order.subtotal + order.tax_amount + 10.00 - 5.00)
    end
  end

  describe '#paid?' do
    let(:order) { create(:order, total: 100.00) }

    it 'returns true when payments cover total' do
      create(:payment, order: order, amount: 100.00, status: 'completed')
      expect(order.paid?).to be true
    end

    it 'returns false when payments are insufficient' do
      create(:payment, order: order, amount: 50.00, status: 'completed')
      expect(order.paid?).to be false
    end
  end

  describe '#balance_due' do
    let(:order) { create(:order, total: 100.00) }

    it 'returns remaining balance' do
      create(:payment, order: order, amount: 60.00, status: 'completed')
      expect(order.balance_due).to eq(40.00)
    end
  end

  describe '#create_shipment!' do
    let(:order) { create(:order, status: 'processing') }

    it 'creates a shipment with tracking info' do
      expect {
        order.create_shipment!(tracking_number: '1Z999AA10123456784', carrier: 'UPS')
      }.to change { order.shipments.count }.by(1)
    end

    it 'transitions order to shipped' do
      order.create_shipment!(tracking_number: '1Z999AA10123456784', carrier: 'UPS')
      expect(order.status).to eq('shipped')
    end
  end
end
