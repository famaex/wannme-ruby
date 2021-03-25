# frozen_string_literal: true

module Wannme
  module APIOperations
    module Request
      module ClassMethods
        def execute_resource_request(method, url, params = {}, opts = {})
          WannmeClient.new.execute_request(method, url, params, opts)
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      protected

      def execute_resource_request(method, url, params = {}, opts = {})
        self.class.execute_resource_request(method, url, params, opts)
      end
    end
  end
end
