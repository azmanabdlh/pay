# frozen_string_literal: true

module Pay
  module Midtrans
    module Webhooks
      class Settlement
        def call(event)
          order_id = event["order_id"]
          return unless order_id

          Pay::Midtrans::Charge.sync_from_order(order_id, object: event)
        end
      end
    end
  end
end
