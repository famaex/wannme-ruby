# frozen_string_literal: true

module Wannme
  class WannmeError < StandardError
    attr_reader :message

    # Response contains a WannmeResponse object that has some basic information
    # about the response that conveyed the error.
    attr_accessor :response

    attr_reader :code
    attr_reader :error
    attr_reader :http_body
    attr_reader :http_headers
    attr_reader :http_status
    attr_reader :json_body # equivalent to #data
    attr_reader :request_id

    # Initializes a WannmeError.
    def initialize(message = nil, http_status: nil, http_body: nil,
                   json_body: nil, http_headers: nil, code: nil)
      @message = message
      @http_status = http_status
      @http_body = http_body
      @json_body = json_body
      @code = code
      @error = construct_error_object
    end

    def construct_error_object
      return nil if @json_body.nil? || !@json_body.key?(:error)

      ErrorObject.construct_from(@json_body[:error])
    end

    def to_s
      status_string = @http_status.nil? ? '' : "(Status #{@http_status}) "
      id_string = @request_id.nil? ? '' : "(Request #{@request_id}) "
      "#{status_string}#{id_string}#{@message}"
    end
  end

  class SignatureVerificationError < WannmeError
    attr_accessor :sig_header

    def initialize(message, sig_header, http_body: nil)
      super(message, http_body: http_body)
      @sig_header = sig_header
    end
  end
end
