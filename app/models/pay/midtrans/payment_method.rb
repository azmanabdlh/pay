# frozen_string_literal: true

module Pay
  module Midtrans
    class PaymentMethod < Pay::PaymentMethod
      def self.sync_from_charge_object(object, customer:, default: false)
        attrs = extract_attributes(object).merge(default: default)
        pay_payment_method = where(customer: customer, processor_id: payment_method_id_from(object)).first_or_initialize
        where(customer: customer).update_all(default: false) if default
        pay_payment_method.update!(attrs)
        pay_payment_method
      end

      def self.payment_method_id_from(object)
        case object["payment_type"]
        when "credit_card"
          object["masked_card"]
        when "bank_transfer"
          object.dig("va_numbers", 0, "va_number") || object["permata_va_number"] || object["bank"]
        else
          object["payment_type"]
        end
      end

      def self.extract_attributes(object)
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
          payment_method_type: payment_type,
          brand: brand,
          last4: last4.to_s,
          bank: bank,
          email: email
        }
      end

      def make_default!
        return if default?

        customer.payment_methods.update_all(default: false)
        update!(default: true)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_midtrans_payment_method, Pay::Midtrans::PaymentMethod
