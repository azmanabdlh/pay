# frozen_string_literal: true

module Pay
  module Midtrans
    class PaymentMethod < Pay::PaymentMethod
      module CardType
        module EWallet
          Gopay = "gopay"
          ShopeePay = "shopeepay"
          Qris = "qris"
          Akulaku = "akulaku"
        end

        BankTransfer = "bank_transfer"
        CreditCard = "credit_card"
        Store = "cstore"
      end

      def self.sync(object, customer:, default: false)
        return if customer.nil?

        attrs = extract_attributes(object)
        processor_id = "order:#{object.order_id}"

        pay_payment_method = find_by(customer: customer, processor_id: processor_id)

        payment_methods.update_all(default: false) if default
        pay_payment_method.update!(attrs.merge(default: default))

        # Reload the Rails association
        reload_default_payment_method if default

        pay_payment_method
      end

      def self.extract_attributes(payment_method)
        payment_type = payment_method[:payment_type]
        case payment_type
        when CardType::EWallet::Gopay, CardType::EWallet::ShopeePay, CardType::EWallet::Qris, CardType::EWallet::Akulaku
          {
            payment_method_type: payment_type,
            brand: payment_type,
            last4: masked.split("-").last.to_s,
            bank: payment_method.dig(:va_numbers, 0, "bank"),
            email: payment_method[:custom_field1].to_s
          }
        when CardType::BankTransfer
          {
            payment_method_type: payment_type,
            brand: brand,
            last4: last4.to_s,
            bank: payment_method.dig(:va_numbers, 0, "bank"),
            email: payment_method[:custom_field1].to_s
          }
        when CardType::CreditCard
          masked = payment_method[:masked_card].to_s
          {
            payment_method_type: payment_type,
            brand: payment_method[:card_type].to_s.capitalize.presence || "Card",
            last4: masked.split("-").last.to_s,
            bank: payment_method.dig(:va_numbers, 0, "bank"),
            email: payment_method[:custom_field1].to_s
          }
        when CardType::CreditCard
          {
            payment_method_type: payment_type,
            brand: payment_method[:card_type].to_s.capitalize.presence || "Card",
            last4: masked.split("-").last.to_s,
            bank: payment_method.dig(:va_numbers, 0, "bank"),
            email: payment_method[:custom_field1].to_s
          }
        when CardType::Store
          masked = payment_method[:masked_card].to_s
          {
            payment_method_type: payment_type,
            brand: object[:store],
            last4: "",
            bank: "store",
            email: payment_method[:custom_field1].to_s
          }
        end
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
