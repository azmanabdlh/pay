# frozen_string_literal: true

module Pay
  module Midtrans
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: 'Pay::Midtrans::Charge'
      has_many :subscriptions, dependent: :destroy, class_name: 'Pay::Midtrans::Subscription'
      has_many :payment_methods, dependent: :destroy, class_name: 'Pay::Midtrans::PaymentMethod'
      has_one :default_payment_method, -> { where(default: true) }, class_name: 'Pay::Midtrans::PaymentMethod'

      def api_record_attributes
        { email: email, name: customer_name }
      end

      def api_record
        with_lock do
          if processor_id?
            ::Midtrans.status(processor_id).data
          else
            update!(processor_id: Pay::NanoId.generate)
            self
          end
        end
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def update_api_record(**_attributes)
        api_record unless processor_id?
        ::Midtrans::Customer.update(processor_id, api_record_attributes.merge(attributes))
      end

      def charge(amount, options = {})
        api_record unless processor_id?

        options[:transaction_details] ||= {}
        options[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        options[:transaction_details][:gross_amount] ||= (amount / 100.0)
        options[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        response = ::Midtrans.charge(options)
        Pay::Midtrans::Charge.sync_from_order(options[:transaction_details][:order_id], object: response.data)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def checkout(**options)
        api_record unless processor_id?

        options[:transaction_details] ||= {}
        options[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        options[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        response = ::Midtrans.create_snap_token(options)
        Pay::Midtrans::Charge.sync_from_order(options[:transaction_details][:order_id], object: response.data)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        api_record unless processor_id?

        options[:name] ||= name
        options[:amount] ||= (options[:amount] || 0) / 100.0
        options[:currency] ||= 'IDR'
        options[:schedule] ||= options[:schedule] || { interval: options[:interval] || 'month',
                                                       interval_count: options[:interval_count] || 1 }
        options[:metadata] ||= { pay_name: name, processor_plan: plan }
        options[:customer_details] ||= {}
        options[:customer_details][:email] ||= email
        options[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        subscription_id = options[:subscription_id] || "sub-#{Pay::NanoId.generate}"
        response = ::Midtrans.create_subscription(options.merge(id: subscription_id))
        Pay::Midtrans::Subscription.sync(subscription_id, object: response.data, name: name)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_customer, Pay::Midtrans::Customer
