# frozen_string_literal: true

require 'spec_helper'

describe Wannme::Webhook do
  describe '#construct_event' do

    subject { Wannme::Webhook.construct_event(payload) }

    context 'when checksum is valid' do
      let(:payload) { File.read('spec/support/valid_webhook.json') }

      it 'creates a new Event resource' do
        expect(subject).to be_a(Wannme::Event)
      end
    end

    context 'when checksum is not valid' do
      let(:payload) { File.read('spec/support/invalid_webhook.json') }

      it 'raises a SignatureVerificationError' do
        expect { subject }.to raise_error(Wannme::SignatureVerificationError)
      end
    end
  end
end
