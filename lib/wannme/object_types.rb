# frozen_string_literal: true

module Wannme
  module ObjectTypes
    def self.object_names_to_classes
      {
        # business objects
        Payment::OBJECT_NAME => Payment
      }
    end
  end
end
