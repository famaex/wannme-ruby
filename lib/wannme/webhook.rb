# frozen_string_literal: true

module Wannme
  module Webhook
    def self.construct_event(payload)
      data = Util.symbolize_names(Util.underscore_names(JSON.parse(payload)))
      Signature.verify_header(data)
      Event.construct_from(data)
    end

    module Signature
      def self.compute_signature(data)
        string = [
          data[:id],
          data[:unique_notification_id],
          data[:partner_reference1],
          Wannme.private_key
        ]

        Digest::SHA1.hexdigest(string.join)
      end

      def self.verify_header(data)
        signature = data[:checksum]
        expected_sig = compute_signature(data)

        unless Util.secure_compare(expected_sig, signature)
          raise SignatureVerificationError.new(
            'No signatures found matching the expected signature for payload',
          )
        end

        true
      end
    end
  end
end
