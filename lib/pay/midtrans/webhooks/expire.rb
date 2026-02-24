# frozen_string_literal: true

module Pay
  module Midtrans
    module Webhooks
      class Expire
        def call(event)
          order_id = event['order_id']
          return unless order_id

          pay_charge = Pay::Midtrans::Charge.sync(order_id, object: event)

          return unless pay_charge && Pay.send_email?(:payment_expire, pay_charge)

          Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).payment_expire.deliver_later
        end
      end
    end
  end
end
