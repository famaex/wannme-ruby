# frozen_string_literal: true

require 'spec_helper'

describe Wannme::WannmeClient do
  describe '.dependant_checksum_values' do
    let(:opts) { { checksum: %i[amount partner_reference1] } }

    context 'when amount is a Float' do
      let(:params) { { amount: amount, partner_reference1: 'ref' } }

      context 'when amount has no decimal part' do
        let(:amount) { 100.0 }

        it 'computes checksum values as if the amount was an integer' do
          return_value = described_class.new.send(:dependant_checksum_values, params, opts)

          expect(return_value).to eq(%w[100 ref])
        end
      end

      context 'when amount has one decimal digit' do
        let(:amount) { 100.50 }

        it 'computes checksum values as if the amount was 2 decimal digits' do
          return_value = described_class.new.send(:dependant_checksum_values, params, opts)

          expect(return_value).to eq(['100.50', 'ref'])
        end
      end

      context 'when amount has 2 decimal digit' do
        let(:amount) { 100.55 }

        it 'computes checksum values as if the amount was 2 decimal digits' do
          return_value = described_class.new.send(:dependant_checksum_values, params, opts)

          expect(return_value).to eq(['100.55', 'ref'])
        end
      end

      context 'when amount has 3 decimal digit' do
        let(:amount) { 100.554 }

        it 'computes checksum values as if the amount was 2 decimal digits' do
          return_value = described_class.new.send(:dependant_checksum_values, params, opts)

          expect(return_value).to eq(['100.55', 'ref'])
        end
      end
    end
  end
end
