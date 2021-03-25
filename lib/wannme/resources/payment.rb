# frozen_string_literal: true

module Wannme
  class Payment < APIResource
    extend Wannme::APIOperations::List
    extend Wannme::APIOperations::Create
    include Wannme::APIOperations::Save

    OBJECT_NAME = 'payment'

    custom_method :cancel, http_verb: :post
    custom_method :reset, http_verb: :post
    custom_method :share, http_verb: :post

    %i[create save].each { |method| checksum_for method, %i[amount partner_reference1] }
    %i[retrieve cancel reset share].each { |method| checksum_for method, [:id] }

    def cancel
      request_wannme_object(
        method: :post,
        path: "#{resource_url}/action/cancel",
        params: { id: id },
        opts: { checksum: [:id] }
      )
    end

    def reset
      request_wannme_object(
        method: :post,
        path: "#{resource_url}/action/reset",
        params: { id: id },
        opts: { checksum: [:id] }
      )
    end

    def share(params = {})
      request_wannme_object(
        method: :post,
        path: "#{resource_url}/action/share",
        params: params.merge(id: id),
        opts: { checksum: [:id] }
      )
    end
  end
end
