# frozen_string_literal: true

module Wannme
  module APIOperations
    module Save
      module ClassMethods
        # Updates an API resource
        #
        # Updates the identified resource with the passed in parameters.
        #
        # ==== Attributes
        #
        # * +id+ - ID of the resource to update.
        # * +params+ - A hash of parameters to pass to the API
        #   {APIOperations::Request.execute_resource_request}.
        def update(id, params = {})
          params.each_key do |k|
            raise ArgumentError, "Cannot update protected field: #{k}" if protected_fields.include?(k)
          end

          resp = execute_resource_request(:post, "#{resource_url}/#{id}", params)
          Util.convert_to_wannme_object(resp.data, self.class::OBJECT_NAME)
        end
      end

      # Creates or updates an API resource.
      #
      # If the resource doesn't yet have an assigned ID and the resource is one
      # that can be created, then the method attempts to create the resource.
      # The resource is updated otherwise.
      #
      # ==== Attributes
      #
      # * +params+ - Overrides any parameters in the resource's serialized data
      #   and includes them in the create or update. If +:req_url:+ is included
      #   in the list, it overrides the update URL used for the create or
      #   update.
      #   {APIOperations::Request.execute_resource_request}.
      def save(params = {})
        # We started unintentionally (sort of) allowing attributes sent to
        # +save+ to override values used during the update. So as not to break
        # the API, this makes that official here.
        update_attributes(params)

        # Now remove any parameters that look like object attributes.
        params = params.reject { |k, _| respond_to?(k) }

        values = serialize_params(self).merge(params)

        # NOTE: that id gets removed here our call to #url above has already
        # generated a uri for this object with an identifier baked in
        values.delete(:id)

        resp = execute_resource_request(:post, save_url, values)
        initialize_from(resp.data)
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      private def save_url
        # This switch essentially allows us "upsert"-like functionality. If the
        # API resource doesn't have an ID set (suggesting that it's new) and
        # its class responds to .create (which comes from
        # Wannme::APIOperations::Create), then use the URL to create a new
        # resource. Otherwise, generate a URL based on the object's identifier
        # for a normal update.
        if self[:id].nil? && self.class.respond_to?(:create)
          self.class.resource_url
        else
          resource_url
        end
      end
    end
  end
end
