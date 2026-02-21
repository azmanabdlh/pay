require "test_helper"

module Pay
  class MidtransControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @routes.draw do
        post "webhooks/midtrans", to: "pay/webhooks/midtrans#create"
      end
    end

    test "should handle post requests" do
      post webhooks_midtrans_path
      assert_response :bad_request
    end

    test "should parse a midtrans webhook" do
      Pay::Webhooks::MidtransController.any_instance.expects(:valid_signature?).returns(true)
      Pay::Webhooks.delegator.expects(:listening?).with("midtrans.settlement").returns(true)

      payload = {
        order_id: "order-101",
        status_code: "200",
        gross_amount: "44000.00",
        signature_key: "x",
        transaction_status: "settlement",
        payment_type: "bank_transfer"
      }

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_midtrans_path, params: payload, as: :json
          assert_response :success
        end
      end
    end

    test "returns bad_request when signature invalid" do
      Pay::Webhooks::MidtransController.any_instance.expects(:valid_signature?).returns(false)

      payload = {
        order_id: "order-102",
        status_code: "200",
        gross_amount: "1000.00",
        signature_key: "bad",
        transaction_status: "pending",
        payment_type: "gopay"
      }

      assert_no_enqueued_jobs only: Pay::Webhooks::ProcessJob do
        assert_no_difference("Pay::Webhook.count") do
          post webhooks_midtrans_path, params: payload, as: :json
          assert_response :bad_request
        end
      end
    end
  end
end
