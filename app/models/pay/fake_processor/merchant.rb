# frozen_string_literal: true

module Pay
  module FakeProcessor
    class Merchant < Pay::Merchant
      def create_account(**_options)
        fake_account = Struct.new(:id).new("fake_account_id")
        update(processor_id: fake_account.id)
        fake_account
      end

      def account_link(refresh_url:, return_url:, type: "account_onboarding", **_options)
        Struct.new(:url).new("/fake_processor/account_link")
      end

      def login_link(**_options)
        Struct.new(:url).new("/fake_processor/login_link")
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_merchant, Pay::FakeProcessor::Merchant
