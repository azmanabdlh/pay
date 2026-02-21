# frozen_string_literal: true

module Pay
  module Midtrans
    class Charge < Pay::Charge
      store_accessor :data, :midtrans_order_id
      store_accessor :data, :transaction_status
      store_accessor :data, :fraud_status
      store_accessor :data, :payment_type

      def self.sync_from_order(order_id, object: nil, try: 0, retries: 1)
        object ||= ::Midtrans.status(order_id).data
        transaction_id = object["transaction_id"] || object["order_id"]
        return unless transaction_id

        pay_charge = find_by(processor_id: transaction_id)
        pay_customer = pay_charge&.customer
        if pay_customer.blank? && (client_ref = object["custom_field1"])
          owner = Pay::Midtrans.find_by_client_reference_id(client_ref)
          pay_customer = Pay::Customer.find_by(owner: owner, processor: :midtrans) if owner
        end
        pay_customer ||= Pay::Customer.find_by(processor: :midtrans)
        return unless pay_customer

        attrs = extract_attributes(object).merge(customer: pay_customer, processor_id: transaction_id)
        if pay_charge
          pay_charge.with_lock { pay_charge.update!(attrs) }
          pay_charge
        else
          created = create!(attrs)
          Pay::Midtrans::PaymentMethod.sync_from_charge_object(object, customer: pay_customer, default: true)
          created
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        raise unless try <= retries

        sleep 0.1
        retry
      end

      def self.extract_attributes(object)
        gross = object["gross_amount"].to_s
        amount_cents = (BigDecimal(gross) * 100).to_i
        status = object["transaction_status"]
        payment_type = object["payment_type"]
        brand = nil
        last4 = nil
        bank = nil
        email = nil

        case payment_type
        when "credit_card"
          masked = object["masked_card"].to_s
          last4 = masked.split("-").last
          brand = object["card_type"].to_s.capitalize.presence || "Card"
        when "bank_transfer"
          bank = if object["bank"] || object.dig("va_numbers", 0,
            "bank") || object["permata_va_number"]
            "permata"
          end
        when "gopay", "shopeepay", "qris", "akulaku"
          brand = payment_type
        when "cstore"
          brand = object["store"]
        end

        {
          object: object,
          amount: amount_cents,
          currency: "idr",
          created_at: Time.zone.parse(object["transaction_time"].to_s),
          payment_method_type: payment_type,
          brand: brand,
          last4: last4.to_s,
          bank: bank,
          email: email,
          metadata: object,
          midtrans_order_id: object["order_id"],
          transaction_status: status,
          fraud_status: object["fraud_status"]
        }
      end

      def api_record
        ::Midtrans.status(data["midtrans_order_id"] || processor_id)
      end

      def refund!(amount_to_refund = nil, **_options)
        amount_to_refund ||= amount
        ::Midtrans.refund(data["midtrans_order_id"] || processor_id, amount: (amount_to_refund / 100.0))
        update!(amount_refunded: amount_refunded + amount_to_refund)
      end

      def capture(**options)
        ::Midtrans.capture(data["midtrans_order_id"] || processor_id, (options[:amount_to_capture] || amount) / 100.0)
        self.class.sync_from_order(data["midtrans_order_id"] || processor_id)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_charge, Pay::Midtrans::Charge
