# frozen_string_literal: true

module Wannme
  module APIOperations
    module Create
      def create(params = {}, opts = {})
        opts.merge!(checksum: get_checksum_for(:create))

        resp = execute_resource_request(:post, resource_url, params, opts)
        Util.convert_to_wannme_object(resp.data, self::OBJECT_NAME)
      end
    end
  end
end
