# frozen_string_literal: true

module Wannme
  class WannmeClient
    include HTTParty
    format :json

    def execute_request(method, path, params = {}, opts = {})
      self.class.base_uri(Wannme.api_base)

      resp = self.class.send(method, path, body: build_json_body(params, opts), headers: default_headers)

      WannmeResponse.from_net_http(resp)
    end

    private

    def build_json_body(params, opts)
      # Add default parameters
      params.merge!(
        partner_id: Wannme.partner_id,
        checksum: checksum(params, opts)
      )

      Util.camelize_names(params).to_json
    end

    def checksum(params, opts)
      string = [Wannme.partner_id, Wannme.private_key] + dependant_checksum_values(params, opts)

      Digest::SHA1.hexdigest(string.join)
    end

    def dependant_checksum_values(params, opts)
      (opts[:checksum] || []).map do |key|
        value = params[key]
        case value
        when Float
          format((value % 1).zero? ? '%d' : '%.2f', value)
        else
          value
        end
      end
    end

    def default_headers
      {
        'Authorization' => Wannme.api_key,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    end
  end
end
