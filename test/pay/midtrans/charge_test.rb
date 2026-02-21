# frozen_string_literal: true

require "test_helper"

class Pay::Midtrans::ChargeTest < ActiveSupport::TestCase
  setup do
    @user = users(:none)
    @pay_customer = Pay::Midtrans::Customer.create!(
      owner: @user,
      processor: :midtrans,
      processor_id: "trx_123",
      default: true
    )

    # Ensure ::Midtrans constant exists for stubbing
    Object.const_set(:Midtrans, Module.new) unless defined?(::Midtrans)
  end

  test "sync creates or updates charge from status" do
    # Fake successful Midtrans status response
    response = ActiveSupport::InheritableOptions.new(
      success?: true,
      data: {
        transaction_id: "trx_123",
        order_id: "order-001",
        gross_amount: 44_000,
        transaction_time: Time.current.iso8601,
        payment_type: "bank_transfer",
        transaction_status: "settlement",
        fraud_status: "accept"
      }
    )

    ::Midtrans.expects(:status).with("order-001").returns(response)

    assert_difference "Pay::Midtrans::Charge.count", +1 do
      charge = Pay::Midtrans::Charge.sync("order-001")
      assert_equal @pay_customer, charge.customer
      assert_equal "order-001", charge.processor_id
      assert_equal 44_000, charge.amount
      assert_equal "idr", charge.currency
      assert_equal "bank_transfer", charge.payment_method_type
      assert_equal "settlement", charge.transaction_status
      assert_equal "accept", charge.fraud_status
    end
  end

  test "api_record delegates to Midtrans.status" do
    charge = @pay_customer.charges.create!(
      processor_id: "order-xyz",
      amount: 12_345,
      payment_method_type: "bank_transfer",
      created_at: Time.zone.now
    )

    fake = ActiveSupport::InheritableOptions.new(success?: true)
    ::Midtrans.expects(:status).with("order-xyz").returns(fake)
    assert_equal fake, charge.api_record
  end

  test "refund! updates amount_refunded" do
    charge = @pay_customer.charges.create!(
      processor_id: "order-refund",
      amount: 20_00,
      amount_refunded: 0,
      payment_method_type: "card",
      created_at: Time.zone.now
    )

    ::Midtrans.expects(:refund).with("order-refund", amount: 20.0).returns(true)
    charge.refund!
    assert_equal 20_00, charge.reload.amount_refunded
  end
end
