# frozen_string_literal: true

require 'spec_helper'

describe Wannme::Payment do
  let(:valid_params) do
    { amount: 100, partner_reference1: 'reference1' }
  end

  describe '#create' do
    context 'when all params are valid' do
      it 'gets and ID from remote service' do
        payment = described_class.create(valid_params)
        expect(payment.id).not_to be_nil
      end
    end
  end

  describe '.retrieve' do
    it 'gets remote data given an ID' do
      payment = Wannme::Payment.create(valid_params)
      retrieved_payment = Wannme::Payment.retrieve(payment.id)
      expect(retrieved_payment.id).to eq(payment.id)
      expect(retrieved_payment.amount).to eq(payment.amount)
      expect(retrieved_payment.partner_reference1).to eq(payment.partner_reference1)
    end
  end

  describe '.cancel' do
    it 'changes status to cancelled' do
      payment = Wannme::Payment.create(valid_params)
      expect do
        payment.cancel
        payment.refresh
      end.to change { payment.status_code }.from('1').to('9')
    end
  end
end
