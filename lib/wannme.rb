# frozen_string_literal: true

# Wannme Ruby bindings
# API spec at https://wannme.com/docs/api
require 'httparty'

# Version
require 'wannme/version'

# API operations
require 'wannme/api_operations/create'
require 'wannme/api_operations/list'
require 'wannme/api_operations/save'
require 'wannme/api_operations/request'

# API resource support classes
require 'wannme/object_types'
require 'wannme/util'
require 'wannme/wannme_client'
require 'wannme/wannme_response'
require 'wannme/wannme_object'
require 'wannme/api_resource'
require 'wannme/wannme_configuration'

# Named API Resource
require 'wannme/resources/payment'

module Wannme
  @configuration = Wannme::WannmeConfiguration.setup

  class << self
    extend Forwardable

    def_delegators :@configuration, :api_key, :api_key=
    def_delegators :@configuration, :api_base, :api_base=
    def_delegators :@configuration, :partner_id, :partner_id=
    def_delegators :@configuration, :private_key, :private_key=
  end
end
