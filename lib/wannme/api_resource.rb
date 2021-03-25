# frozen_string_literal: true

module Wannme
  class APIResource < WannmeObject
    include Wannme::APIOperations::Request

    @@checksum_params = {}

    def self.class_name
      name.split('::')[-1]
    end

    # Adds a custom method to a resource class. This is used to add support for
    # non-CRUDL API requests, e.g. capturing charges. custom_method takes the
    # following parameters:
    # - name: the name of the custom method to create (as a symbol)
    # - http_verb: the HTTP verb for the API request (:get, :post, or :delete)
    # - http_path: the path to append to the resource's URL. If not provided,
    #              the name is used as the path
    #
    # For example, this call:
    #     custom_method :capture, http_verb: post
    # adds a `capture` class method to the resource class that, when called,
    # will send a POST request to `/v1/<object_name>/capture`.
    def self.custom_method(name, http_verb:, http_path: nil)
      unless %i[get post delete].include?(http_verb)
        raise ArgumentError,
              "Invalid http_verb value: #{http_verb.inspect}. Should be one " \
              'of :get, :post or :delete.'
      end
      http_path ||= name.to_s
      define_singleton_method(name) do |id, params = {}, _opts = {}|
        unless id.is_a?(String)
          raise ArgumentError,
                'id should be a string representing the ID of an API resource'
        end

        url = "#{resource_url}/#{CGI.escape(id)}/#{CGI.escape(http_path)}"
        resp = execute_resource_request(http_verb, url, params)
        Util.convert_to_wannme_object(resp.data)
      end
    end

    def self.checksum_for(method, params)
      @@checksum_params[method] = params
    end

    def self.get_checksum_for(method)
      @@checksum_params[method]
    end

    def self.resource_url
      if self == APIResource
        raise NotImplementedError,
              'APIResource is an abstract class. You should perform actions ' \
              'on its subclasses (Charge, Customer, etc.)'
      end
      # Namespaces are separated in object names with periods (.) and in URLs
      # with forward slashes (/), so replace the former with the latter.
      "/integration/v2/wannmepay/#{self::OBJECT_NAME}/"
    end

    def resource_url
      unless (id = self['id'])
        raise InvalidRequestError.new(
          "Could not determine which URL to request: #{self.class} instance " \
          "has invalid ID: #{id.inspect}",
          'id'
        )
      end
      [self.class.resource_url, CGI.escape(id)].join
    end

    def refresh
      resp = execute_resource_request(:get, resource_url, { id: id }, checksum: [:id])
      initialize_from(resp.data)
    end

    def self.retrieve(id)
      instance = new(id)
      instance.refresh
      instance
    end

    protected

    def request_wannme_object(method:, path:, params:, opts:)
      resp = execute_resource_request(method, path, params, opts)

      # If we're getting back this thing, update; otherwise, instantiate.
      if Util.object_name_matches_class?(resp.data[:object], self.class)
        initialize_from(resp.data)
      else
        Util.convert_to_wannme_object(resp.data)
      end
    end
  end
end
