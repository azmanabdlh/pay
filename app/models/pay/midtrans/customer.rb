# frozen_string_literal: true

module Pay
  module Midtrans
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: 'Pay::Midtrans::Charge'
      has_many :subscriptions, dependent: :destroy, class_name: 'Pay::Midtrans::Subscription'
      has_many :payment_methods, dependent: :destroy, class_name: 'Pay::Midtrans::PaymentMethod'
      has_one :default_payment_method, -> { where(default: true) }, class_name: 'Pay::Midtrans::PaymentMethod'

      def api_record
        with_lock do
          if processor_id?
            ::Midtrans.status(processor_id).data
          else
            update!(processor_id: Pay::NanoId.generate)
            self
          end
        end
      rescue MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def update_api_record(**attributes)
        api_record
      end

      def charge(amount, options = {})
        api_record unless processor_id?

        payload = options[:payload] || {}
        payload[:transaction_details] ||= {}
        payload[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        payload[:transaction_details][:gross_amount] ||= (amount / 100.0)
        payload[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        response = ::Midtrans.charge(payload)
        Pay::Midtrans::Charge.sync_from_order(payload[:transaction_details][:order_id], object: response.data)
      end

      def checkout(**options)
        api_record unless processor_id?
        payload = options[:payload] || {}
        payload[:transaction_details] ||= {}
        payload[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        payload[:transaction_details][:gross_amount] ||= (amount / 100.0)
        payload[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        response = ::Midtrans.create_snap_token(payload)
        Pay::Midtrans::Charge.sync_from_order(payload[:transaction_details][:order_id], object: response.data)
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        api_record unless processor_id?
        payload = options[:payload] || {}
        payload[:name] ||= name
        payload[:amount] ||= (options[:amount] || 0) / 100.0
        payload[:currency] ||= 'IDR'
        payload[:schedule] ||= options[:schedule] || { interval: options[:interval] || 'month',
                                                       interval_count: options[:interval_count] || 1 }
        payload[:metadata] ||= { pay_name: name, processor_plan: plan }
        payload[:customer_details] ||= {}
        payload[:customer_details][:email] ||= email
        payload[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        subscription_id = options[:subscription_id] || "sub-#{Pay::NanoId.generate}"
        response = ::Midtrans.create_subscription(payload.merge(id: subscription_id))
        Pay::Midtrans::Subscription.sync(subscription_id, object: response.data, name: name)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_customer, Pay::Midtrans::Customer
