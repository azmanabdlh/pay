# frozen_string_literal: true

module Pay
  module Midtrans
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::Midtrans::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::Midtrans::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::Midtrans::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::Midtrans::PaymentMethod"

      def api_record_attributes
        {email: email, name: customer_name}
      end

      def api_record
        update!(processor_id: Pay::NanoId.generate)
        self
      end

      def update_api_record(**attributes)
        api_record unless processor_id?
        update(processor_id: processor_id, **api_record_attributes.merge(attributes))
      end

      def charge(amount, options = {})
        api_record unless processor_id?

        options[:transaction_details] ||= {}
        options[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        options[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        response = ::Midtrans.charge(options)
        Pay::Midtrans::Charge.sync(options[:transaction_details][:order_id], object: response.data)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def checkout(**options)
        api_record unless processor_id?

        options[:transaction_details] ||= {}
        options[:transaction_details][:order_id] ||= "midtrans-#{Pay::NanoId.generate}"
        options[:custom_field1] ||= Pay::Midtrans.to_client_reference_id(owner)
        ::Midtrans.create_snap_token(options)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        raise Pay::Error, "Midtrans subscription is not supported by this adapter yet. See: https://github.com/veritrans/veritrans-ruby/tree/master?tab=readme-ov-file#22d-subscription-api"
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_customer, Pay::Midtrans::Customer
