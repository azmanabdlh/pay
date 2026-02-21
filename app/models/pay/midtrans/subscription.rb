# frozen_string_literal: true

module Pay
  module Midtrans
    class Subscription < Pay::Subscription
      attr_writer :api_record

      def self.sync(subscription_id, object: nil, name: nil, try: 0, retries: 1)
        object ||= ::Midtrans.get_subscription(subscription_id).data

        pay_customer = Pay::Customer.find_by(processor: :midtrans)
        return unless pay_customer

        attributes = extract_attributes(object).merge(
          metadata: object,
          stripe_account: nil
        )

        pay_subscription = find_by(customer: pay_customer, processor_id: subscription_id)
        if pay_subscription
          pay_subscription.with_lock { pay_subscription.update!(attributes) }
        else
          name ||= object["name"] || Pay.default_product_name
          pay_subscription = create!(attributes.merge(customer: pay_customer, name: name,
            processor_id: subscription_id))
        end

        pay_subscription.api_record = object
        pay_subscription
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        raise unless try <= retries

        sleep 0.1
        retry
      end

      def self.extract_attributes(object)
        status = object["status"].to_s
        mapped_status = case status
        when "active" then "active"
        when "paused" then "paused"
        else "canceled"
        end

        {
          object: object,
          processor_plan: object["name"].to_s,
          quantity: 1,
          status: mapped_status,
          metered: false,
          application_fee_percent: nil,
          pause_behavior: ((mapped_status == "paused") ? "void" : nil),
          pause_resumes_at: nil,
          current_period_start: nil,
          current_period_end: parse_time(object["next_execution_at"]),
          trial_ends_at: nil,
          ends_at: ((mapped_status == "canceled") ? Time.current : nil),
          payment_method_id: nil
        }
      end

      def api_record
        @api_record ||= ::Midtrans.get_subscription(processor_id).data
      end

      def cancel(**_options)
        return if canceled?

        ::Midtrans.disable_subscription(processor_id)
        update(ends_at: Time.current, status: :canceled)
      end

      def cancel_now!(**options)
        cancel(**options)
      end

      def resume
        ::Midtrans.enable_subscription(processor_id)
        update(ends_at: nil, status: :active)
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        @api_record = ::Midtrans.update_subscription(processor_id, {name: plan}.merge(options))
        sync!(object: @api_record)
      end

      def pay_open_invoices
      end

      private

      def parse_time(value)
        Time.zone.parse(value.to_s)
      rescue
        nil
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_subscription, Pay::Midtrans::Subscription
