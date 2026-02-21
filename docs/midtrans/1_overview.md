# Using Pay with Midtrans

This guide explains how to integrate Midtrans with Pay as an additional payment processor, covering setup, charging, Snap checkout, subscriptions, and webhooks.

## Prerequisites

- A Midtrans account with access to Server Key and Client Key
- The Ruby Midtrans SDK installed in your app:

```ruby
gem "veritas" # Official Midtrans Ruby SDK
```

```bash
bundle install
```

## Credentials

Pay reads Midtrans credentials from either Rails credentials or environment variables. Add your keys to Rails credentials:

```yaml
# rails credentials:edit
midtrans:
  server_key: <YOUR_SERVER_KEY>
  client_key: <YOUR_CLIENT_KEY>
  # Optional; defaults to sandbox
  # api_host: https://api.midtrans.com
```

Or set via environment variables:

- `MIDTRANS_SERVER_KEY`
- `MIDTRANS_CLIENT_KEY`
- `MIDTRANS_API_HOST` (optional; defaults to https://api.sandbox.midtrans.com)

## Enable Midtrans

Set Midtrans as your processor for a billable model:

```ruby
# In your application model (e.g., User)
class User < ApplicationRecord
  pay_customer
end

user.set_payment_processor :midtrans
```

## Charging via Core API

Charge directly through Midtrans Core API using `user.payment_processor.charge`. Amount is expressed in minor units (cents); Pay converts to gross_amount for Midtrans:

```ruby
user.payment_processor.charge({
    payment_type: "bank_transfer",
    bank_transfer: { bank: "permata" },
    transaction_details: {
      order_id: "midtrans-#{SecureRandom.hex(8)}"
      # gross_amount will be set automatically from the amount above
    },
    # client reference for Pay → owner mapping
    custom_field1: Pay::Midtrans.to_client_reference_id(user)
  }
)
```

Under the hood, this calls `Midtrans.charge` and syncs the resulting charge by `order_id`.

### Troubleshooting 401 Unauthorized

If you receive “Unknown Merchant server_key/id (401)”, verify:
- Server Key matches the environment (Sandbox vs Production)
- `MIDTRANS_API_HOST` points to the correct environment
- Credentials are loaded (check `Midtrans.config.server_key` in Rails console)

## Snap Checkout

Generate a Snap token and sync the pending charge by `order_id`:

```ruby
user.payment_processor.checkout({
   transaction_details: {
    order_id: "test-transaction-order-123",
    gross_amount: 100000,
    secure: true
  }
})
```

Initialize Snap JS when customer click pay button.
```html
<html>
  <body>
    <button id="pay-button">Pay!</button>
    <pre><div id="result-json">JSON result will appear here after payment:<br></div></pre> 

<!-- TODO: Remove ".sandbox" from script src URL for production environment. Also input your client key in "data-client-key" -->
    <script src="https://app.sandbox.midtrans.com/snap/snap.js" data-client-key="<Set your ClientKey here>"></script>
    <script type="text/javascript">
      document.getElementById('pay-button').onclick = function(){
        // SnapToken acquired from previous step
        snap.pay('PUT_TRANSACTION_TOKEN_HERE', {
          // Optional
          onSuccess: function(result){
            /* You may add your own js here, this is just example */ document.getElementById('result-json').innerHTML += JSON.stringify(result, null, 2);
          },
          // Optional
          onPending: function(result){
            /* You may add your own js here, this is just example */ document.getElementById('result-json').innerHTML += JSON.stringify(result, null, 2);
          },
          // Optional
          onError: function(result){
            /* You may add your own js here, this is just example */ document.getElementById('result-json').innerHTML += JSON.stringify(result, null, 2);
          }
        });
      };
    </script>
  </body>
</html>
```


## Subscriptions
Comming soon...



## Webhooks

Midtrans webhooks are received at:

```
POST /pay/webhooks/midtrans
```

Pay validates signatures using SHA‑512 over `order_id + status_code + gross_amount + server_key`.

Events handled:
- settlement → sync charge
- pending → sync charge
- deny → sync charge
- expire → sync charge
- capture → sync charge


## Emails

Pay includes user emails for failed or action-required payments. For Midtrans specifically, custom emails are available for:
- deny → `Pay::UserMailer.payment_deny`
- expire → `Pay::UserMailer.payment_expire`
