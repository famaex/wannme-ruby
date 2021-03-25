# frozen_string_literal: true

module Wannme
  class WannmeConfiguration
    attr_accessor :api_key, :api_base, :partner_id, :private_key

    def self.setup
      new.tap do |instance|
        yield(instance) if block_given?
      end
    end

    def initialize
      @api_base = 'https://api.wannme.com'
    end
  end
end
