# frozen_string_literal: true

require 'cgi'

module Wannme
  module Util
    def self.object_classes
      @object_classes ||= Wannme::ObjectTypes.object_names_to_classes
    end

    def self.object_name_matches_class?(object_name, klass)
      Util.object_classes[object_name] == klass
    end

    # Converts a hash of fields or an array of hashes into a +WannmeObject+ or
    # array of +WannmeObject+s. These new objects will be created as a concrete
    # type as dictated by their `object` field (e.g. an `object` value of
    # `charge` would create an instance of +Charge+), but if `object` is not
    # present or of an unknown type, the newly created instance will fall back
    # to being a +WannmeObject+.
    #
    # ==== Attributes
    #
    # * +data+ - Hash of fields and values to be converted into a WannmeObject.
    def self.convert_to_wannme_object(data, object_type = nil)
      case data
      when Array
        data.map { |element| convert_to_wannme_object(element, object_type) }
      when Hash
        # Try converting to a known object class.  If none available, fall back
        # to generic WannmeObject
        object_classes.fetch(object_type, WannmeObject).construct_from(data)
      else
        data
      end
    end

    def self.camelize_names(object)
      case object
      when Hash
        new_hash = {}
        object.each do |key, value|
          key = (begin
            string = key.to_s
            string = string.sub(/^(?:(?=\b|[A-Z_])|\w)/) { |match| match.downcase }
            string.gsub(%r{(?:_|(/))([a-z\d]*)}) do
              "#{Regexp.last_match(1)}#{Regexp.last_match(2).capitalize}"
            end.gsub('/', '::')
          rescue StandardError
            key
          end) || key
          new_hash[key] = camelize_names(value)
        end
        new_hash
      when Array
        object.map { |value| symbolize_names(value) }
      else
        object
      end
    end

    def self.underscore_names(object)
      case object
      when Hash
        new_hash = {}
        object.each do |key, value|
          key = (begin
            key.to_s.gsub(/::/, '/')
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .tr('-', '_')
              .downcase
          rescue StandardError
            key
          end) || key
          new_hash[key] = underscore_names(value)
        end
        new_hash
      when Array
        object.map { |value| underscore_names(value) }
      else
        object
      end
    end

    def self.symbolize_names(object)
      case object
      when Hash
        new_hash = {}
        object.each do |key, value|
          key = (begin
            key.to_sym
          rescue StandardError
            key
          end) || key
          new_hash[key] = symbolize_names(value)
        end
        new_hash
      when Array
        object.map { |value| symbolize_names(value) }
      else
        object
      end
    end

    # Encodes a hash of parameters in a way that's suitable for use as query
    # parameters in a URI or as form parameters in a request body. This mainly
    # involves escaping special characters from parameter keys and values (e.g.
    # `&`).
    def self.encode_parameters(params)
      Util.flatten_params(params)
          .map { |k, v| "#{url_encode(k)}=#{url_encode(v)}" }.join('&')
    end

    # Encodes a string in a way that makes it suitable for use in a set of
    # query parameters in a URI or in a set of form parameters in a request
    # body.
    def self.url_encode(key)
      CGI.escape(key.to_s).
        # Don't use strict form encoding by changing the square bracket control
        # characters back to their literals. This is fine by the server, and
        # makes these parameter strings easier to read.
        gsub('%5B', '[').gsub('%5D', ']')
    end

    def self.flatten_params(params, parent_key = nil)
      result = []

      # do not sort the final output because arrays (and arrays of hashes
      # especially) can be order sensitive, but do sort incoming parameters
      params.each do |key, value|
        calculated_key = parent_key ? "#{parent_key}[#{key}]" : key.to_s
        if value.is_a?(Hash)
          result += flatten_params(value, calculated_key)
        elsif value.is_a?(Array)
          result += flatten_params_array(value, calculated_key)
        else
          result << [calculated_key, value]
        end
      end

      result
    end

    def self.flatten_params_array(value, calculated_key)
      result = []
      value.each_with_index do |elem, i|
        if elem.is_a?(Hash)
          result += flatten_params(elem, "#{calculated_key}[#{i}]")
        elsif elem.is_a?(Array)
          result += flatten_params_array(elem, calculated_key)
        else
          result << ["#{calculated_key}[#{i}]", elem]
        end
      end
      result
    end

    # `Time.now` can be unstable in cases like an administrator manually
    # updating its value or a reconcilation via NTP. For this reason, prefer
    # the use of the system's monotonic clock especially where comparing times
    # to calculate an elapsed duration.
    #
    # Shortcut for getting monotonic time, mostly for purposes of line length
    # and test stubbing. Returns time in seconds since the event used for
    # monotonic reference purposes by the platform (e.g. system boot time).
    def self.monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def self.normalize_id(id)
      if id.is_a?(Hash) # overloaded id
        params_hash = id.dup
        id = params_hash.delete(:id)
      else
        params_hash = {}
      end
      [id, params_hash]
    end

    # The secondary opts argument can either be a string or hash
    # Turn this value into an api_key and a set of headers
    def self.normalize_opts(opts)
      case opts
      when String
        { api_key: opts }
      when Hash
        check_api_key!(opts.fetch(:api_key)) if opts.key?(:api_key)
        opts.clone
      else
        raise TypeError, 'normalize_opts expects a string or a hash'
      end
    end

    def self.check_string_argument!(key)
      raise TypeError, 'argument must be a string' unless key.is_a?(String)

      key
    end

    def self.check_api_key!(key)
      raise TypeError, 'api_key must be a string' unless key.is_a?(String)

      key
    end

    # Normalizes header keys so that they're all lower case and each
    # hyphen-delimited section starts with a single capitalized letter. For
    # example, `request-id` becomes `Request-Id`. This is useful for extracting
    # certain key values when the user could have set them with a variety of
    # diffent naming schemes.
    def self.normalize_headers(headers)
      headers.each_with_object({}) do |(k, v), new_headers|
        k = k.to_s.tr('_', '-') if k.is_a?(Symbol)
        k = k.split('-').reject(&:empty?).map(&:capitalize).join('-')

        new_headers[k] = v
      end
    end

    # Constant time string comparison to prevent timing attacks
    # Code borrowed from ActiveSupport
    def self.secure_compare(str_a, str_b)
      return false unless str_a.bytesize == str_b.bytesize

      l = str_a.unpack "C#{str_a.bytesize}"

      res = 0
      str_b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
