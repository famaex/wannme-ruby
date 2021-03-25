# frozen_string_literal: true

module Wannme
  # WannmeResponse encapsulates some vitals of a response that came back from
  # the Wannme API.
  class WannmeResponse
    # The data contained by the HTTP body of the response deserialized from
    # JSON.
    attr_accessor :data

    # The raw HTTP body of the response.
    attr_accessor :http_body

    # The integer HTTP status code of the response.
    attr_accessor :http_status

    # Initializes a WannmeResponse object from a Net::HTTP::HTTPResponse
    # object.
    def self.from_net_http(http_resp)
      resp = WannmeResponse.new
      resp.http_body = http_resp.body
      resp.http_status = http_resp.code.to_i
      resp.data = parse_response(http_resp)
      resp
    end

    def self.parse_response(http_resp)
      return {} unless http_resp.body && !http_resp.body.empty?

      Util.symbolize_names(
        Util.underscore_names(
          JSON.parse(http_resp.body)
        )
      )
    end
  end
end
