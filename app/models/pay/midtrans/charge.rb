# frozen_string_literal: true

module Pay
  module Midtrans
    class Charge < Pay::Charge
      store_accessor :data, :midtrans_order_id
      store_accessor :data, :transaction_status
      store_accessor :data, :fraud_status
      store_accessor :data, :payment_type

      def self.sync(order_id, object: nil, try: 0, retries: 1)
        response ||= ::Midtrans.status(order_id)
        return unless response.success?

        object = response.data
        transaction_id = object[:transaction_id]
        order_id = object[:order_id]

        pay_customer = Pay::Customer.find_by(processor: :midtrans, processor_id: transaction_id)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object[:owner]} is not in the database while syncing Midtrans Charge #{transaction_id}"
          return
        end

        brand = nil
        last4 = nil
        bank = nil
        email = nil

        if object.key?(:masked_card)
          masked = object[:masked_card].to_s
          last4 = masked.split("-").last
          brand = object[:card_type].to_s.capitalize.presence || "Card"
        end

        if object.key?(:bank_transfer)
          bank = object.dig(:va_numbers, 0, "bank").to_s || object[:bank].to_s || object[:permata_va_number].to_s
        end

        attrs = {
          object: object.to_hash,
          amount: object[:gross_amount],
          currency: "idr",
          created_at: Time.zone.parse(object[:transaction_time].to_s),
          payment_method_type: object[:payment_type],
          brand: brand || object[:store] || object[:payment_type],
          last4: last4.to_s,
          bank: bank,
          email: object[:custom_field1].to_s,
          metadata: object,
          midtrans_order_id: object[:order_id],
          transaction_status: object[:transaction_status],
          fraud_status: object[:fraud_status]
        }

        # Update or create the charge
        if (pay_charge = find_by(customer: pay_customer, processor_id: order_id))
          pay_charge.with_lock { pay_charge.update!(attrs) }
          pay_charge
        else
          create!(attrs.merge(customer: pay_customer, processor_id: order_id))
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        raise unless try <= retries

        sleep 0.1
        retry
      end

      def api_record
        ::Midtrans.status(processor_id)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end

      def refund!(amount_to_refund = nil, **_options)
        amount_to_refund ||= amount
        ::Midtrans.refund(processor_id, amount: (amount_to_refund / 100.0))
        update!(amount_refunded: amount_refunded + amount_to_refund)
      rescue ::MidtransError => e
        raise Pay::Midtrans::Error, e.message
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_charge, Pay::Midtrans::Charge
