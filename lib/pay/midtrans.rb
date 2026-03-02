# frozen_string_literal: true

module Pay
  module Midtrans
    class Error < Pay::Error
      delegate :message, to: :cause
    end

    module Webhooks
      autoload :Settlement, "pay/midtrans/webhooks/settlement"
      autoload :Pending, "pay/midtrans/webhooks/pending"
      autoload :Deny, "pay/midtrans/webhooks/deny"
      autoload :Expire, "pay/midtrans/webhooks/expire"
      autoload :Capture, "pay/midtrans/webhooks/capture"
    end

    extend Env

    mattr_accessor :model_names, default: Set.new

    def self.enabled?
      Pay.enabled_processors.include?(:midtrans) && defined?(::Midtrans)
    end

    def self.setup
      ::Midtrans.config.server_key = server_key
      ::Midtrans.config.client_key = client_key
      ::Midtrans.config.api_host = api_host
    end

    def self.server_key
      find_value_by_name(:midtrans, :server_key)
    end

    def self.client_key
      find_value_by_name(:midtrans, :client_key)
    end

    def self.api_host
      find_value_by_name(:midtrans, :api_host) || "https://api.sandbox.midtrans.com"
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "midtrans.settlement", Pay::Midtrans::Webhooks::Settlement.new
        events.subscribe "midtrans.pending", Pay::Midtrans::Webhooks::Pending.new
        events.subscribe "midtrans.deny", Pay::Midtrans::Webhooks::Deny.new
        events.subscribe "midtrans.expire", Pay::Midtrans::Webhooks::Expire.new
        events.subscribe "midtrans.capture", Pay::Midtrans::Webhooks::Capture.new
      end
    end

    def self.retrieve(id)
      response = ::Midtrans.status(id)
      return response.data if response.success?

      nil
    end

    def self.to_client_reference_id(record)
      unless model_names.include?(record.class.name)
        raise ArgumentError, "#{record.class.name} does not include Pay. Allowed models: #{model_names.to_a.join(", ")}"
      end

      record.email || [record.class.name, record.id].join("_")
    end

    def self.find_by_client_reference_id(client_reference_id)
      model_name, id = client_reference_id.split("_", 2)
      return unless model_names.include?(model_name)

      model_name.constantize.find(id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "[Pay] Unable to locate record with: #{client_reference_id}"
      nil
    end
  end
end
