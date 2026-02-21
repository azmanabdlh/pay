# frozen_string_literal: true

module Pay
  module Webhooks
    class MidtransController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        event = parsed_event
        if valid_signature?(event)
          queue_event(event)
          head :ok
        else
          head :bad_request
        end
      rescue JSON::ParserError
        head :bad_request
      end

      private

      def queue_event(event)
        type = event["transaction_status"]
        return unless Pay::Webhooks.delegator.listening?("midtrans.#{type}")

        record = Pay::Webhook.create!(processor: :midtrans, event_type: type, event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def parsed_event
        JSON.parse(request.body.read)
      end

      def valid_signature?(event)
        order_id = event["order_id"]
        status_code = event["status_code"]
        gross_amount = event["gross_amount"]
        signature_key = event["signature_key"]
        secret = Pay::Midtrans.signing_secret.to_s
        return false if [order_id, status_code, gross_amount, signature_key, secret].any?(&:blank?)

        payload = "#{order_id}#{status_code}#{gross_amount}#{secret}"
        expected = Digest::SHA512.hexdigest(payload)
        ActiveSupport::SecurityUtils.secure_compare(signature_key, expected)
      end
    end
  end
end
