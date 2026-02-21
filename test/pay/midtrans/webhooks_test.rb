# frozen_string_literal: true

require "test_helper"

class Pay::Midtrans::WebhooksTest < ActiveSupport::TestCase
  setup do
    @user = users(:none)
    @pay_customer = Pay::Midtrans::Customer.create!(
      owner: @user,
      processor: :midtrans,
      processor_id: "trx_mail",
      default: true
    )
    @charge = @pay_customer.charges.create!(
      processor_id: "order-mail",
      amount: 10_00,
      payment_method_type: "bank_transfer",
      created_at: Time.zone.now
    )
  end

  test "settlement webhook calls charge sync" do
    event = {"order_id" => "order-abc"}
    Pay::Midtrans::Charge.expects(:sync).with("order-abc", object: event)
    Pay::Midtrans::Webhooks::Settlement.new.call(event)
  end

  test "pending webhook calls charge sync" do
    event = {"order_id" => "order-pending"}
    Pay::Midtrans::Charge.expects(:sync).with("order-pending", object: event)
    Pay::Midtrans::Webhooks::Pending.new.call(event)
  end

  test "capture webhook calls charge sync" do
    event = {"order_id" => "order-capture"}
    Pay::Midtrans::Charge.expects(:sync).with("order-capture", object: event)
    Pay::Midtrans::Webhooks::Capture.new.call(event)
  end

  test "deny webhook sends email when enabled" do
    Pay.emails.payment_deny = true

    event = {"order_id" => @charge.processor_id}
    Pay::Midtrans::Charge.stubs(:sync).returns(@charge)

    assert_enqueued_emails 1 do
      Pay::Midtrans::Webhooks::Deny.new.call(event)
    end
  ensure
    Pay.emails.delete_field(:payment_deny) if Pay.emails.respond_to?(:delete_field)
  end

  test "expire webhook sends email when enabled" do
    Pay.emails.payment_expire = true

    event = {"order_id" => @charge.processor_id}
    Pay::Midtrans::Charge.stubs(:sync).returns(@charge)

    assert_enqueued_emails 1 do
      Pay::Midtrans::Webhooks::Expire.new.call(event)
    end
  ensure
    Pay.emails.delete_field(:payment_expire) if Pay.emails.respond_to?(:delete_field)
  end
end

