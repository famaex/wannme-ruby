# frozen_string_literal: true

module Wannme
  module APIOperations
    module List
      def list(filters = {}, opts = {})
        resp, opts = execute_resource_request(:get, resource_url + '/search', filters, opts)
      end
    end
  end
end
