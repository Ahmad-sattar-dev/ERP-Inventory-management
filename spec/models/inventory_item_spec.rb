# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryItem, type: :model do
  describe 'associations' do
    it { should belong_to(:product_variant) }
    it { should belong_to(:location) }
    it { should have_many(:inventory_movements).dependent(:destroy) }
    it { should have_many(:stock_reservations).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }

    it 'validates uniqueness of product_variant scoped to location' do
      existing = create(:inventory_item)
      duplicate = build(:inventory_item,
                        product_variant: existing.product_variant,
                        location: existing.location)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:available_item) { create(:inventory_item, status: 'available', quantity: 10) }
    let!(:reserved_item) { create(:inventory_item, status: 'reserved', quantity: 5) }
    let!(:low_stock_item) { create(:inventory_item, quantity: 2, reorder_point: 5) }
    let!(:out_of_stock_item) { create(:inventory_item, quantity: 0) }

    describe '.available' do
      it 'returns only available items' do
        expect(described_class.available).to include(available_item)
        expect(described_class.available).not_to include(reserved_item)
      end
    end

    describe '.low_stock' do
      it 'returns items below reorder point' do
        expect(described_class.low_stock).to include(low_stock_item)
        expect(described_class.low_stock).not_to include(available_item)
      end
    end

    describe '.out_of_stock' do
      it 'returns items with zero quantity' do
        expect(described_class.out_of_stock).to include(out_of_stock_item)
        expect(described_class.out_of_stock).not_to include(available_item)
      end
    end
  end

  describe '.adjust_stock' do
    let(:variant) { create(:product_variant) }
    let(:location) { create(:location) }

    context 'when item does not exist' do
      it 'creates a new inventory item' do
        expect {
          described_class.adjust_stock(
            variant_id: variant.id,
            location_id: location.id,
            quantity: 10,
            reason: 'initial_stock'
          )
        }.to change(described_class, :count).by(1)
      end

      it 'sets the correct quantity' do
        item = described_class.adjust_stock(
          variant_id: variant.id,
          location_id: location.id,
          quantity: 10,
          reason: 'initial_stock'
        )
        expect(item.quantity).to eq(10)
      end
    end

    context 'when item exists' do
      let!(:item) { create(:inventory_item, product_variant: variant, location: location, quantity: 20) }

      it 'adjusts quantity by the specified amount' do
        described_class.adjust_stock(
          variant_id: variant.id,
          location_id: location.id,
          quantity: -5,
          reason: 'sale'
        )
        expect(item.reload.quantity).to eq(15)
      end

      it 'creates an inventory movement record' do
        expect {
          described_class.adjust_stock(
            variant_id: variant.id,
            location_id: location.id,
            quantity: -5,
            reason: 'sale'
          )
        }.to change { item.inventory_movements.count }.by(1)
      end

      it 'raises error when reducing below zero' do
        expect {
          described_class.adjust_stock(
            variant_id: variant.id,
            location_id: location.id,
            quantity: -25,
            reason: 'sale'
          )
        }.to raise_error(NegativeStockError)
      end
    end
  end

  describe '#reserve!' do
    let(:item) { create(:inventory_item, quantity: 10, reserved_quantity: 0) }
    let(:order) { create(:order) }

    it 'creates a stock reservation' do
      expect {
        item.reserve!(5, order: order)
      }.to change { item.stock_reservations.count }.by(1)
    end

    it 'increases reserved quantity' do
      item.reserve!(5, order: order)
      expect(item.reload.reserved_quantity).to eq(5)
    end

    it 'raises error when insufficient stock' do
      expect {
        item.reserve!(15, order: order)
      }.to raise_error(InsufficientStockError)
    end
  end

  describe '#fulfill!' do
    let(:item) { create(:inventory_item, quantity: 10) }

    it 'reduces quantity' do
      item.fulfill!(3)
      expect(item.reload.quantity).to eq(7)
    end

    it 'raises error when insufficient stock' do
      expect {
        item.fulfill!(15)
      }.to raise_error(InsufficientStockError)
    end
  end

  describe '#low_stock?' do
    it 'returns true when quantity is at or below reorder point' do
      item = create(:inventory_item, quantity: 5, reorder_point: 10)
      expect(item.low_stock?).to be true
    end

    it 'returns false when quantity is above reorder point' do
      item = create(:inventory_item, quantity: 15, reorder_point: 10)
      expect(item.low_stock?).to be false
    end

    it 'returns false when reorder point is not set' do
      item = create(:inventory_item, quantity: 5, reorder_point: nil)
      expect(item.low_stock?).to be false
    end
  end

  describe 'callbacks' do
    describe 'low stock alert' do
      it 'enqueues alert job when quantity drops below reorder point' do
        item = create(:inventory_item, quantity: 10, reorder_point: 5)

        expect {
          item.update!(quantity: 3)
        }.to have_enqueued_job(LowStockAlertJob).with(item.id)
      end
    end
  end
end
