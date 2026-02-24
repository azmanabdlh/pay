# frozen_string_literal: true

require "test_helper"

class Pay::Midtrans::ProcessorTest < ActiveSupport::TestCase
  test "finds API keys from env" do
    old_env = ENV.to_hash
    ENV.update(
      "MIDTRANS_SERVER_KEY" => "server_x",
      "MIDTRANS_CLIENT_KEY" => "client_y",
      "MIDTRANS_API_HOST" => "https://api.midtrans.com"
    )

    assert_equal "server_x", Pay::Midtrans.server_key
    assert_equal "client_y", Pay::Midtrans.client_key
    assert_equal "https://api.midtrans.com", Pay::Midtrans.api_host
  ensure
    ENV.update(old_env)
  end

  test "can generate a client_reference_id for a model" do
    user = users(:none)
    Pay::Midtrans.model_names << user.class.name
    assert_equal user.email, Pay::Midtrans.to_client_reference_id(user)
  end

  test "raises an error for client_reference_id if the object does not use Pay" do
    assert_raises ArgumentError do
      Pay::Midtrans.to_client_reference_id("not-a-user-instance")
    end
  end

  test "can find a record by client_reference_id" do
    user = users(:none)
    Pay::Midtrans.model_names << user.class.name
    assert_equal user, Pay::Midtrans.find_by_client_reference_id("User_#{user.id}")
  end
end
