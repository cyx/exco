require 'open3'
require 'uri'
require 'date'

module Exco
  Error = Class.new(StandardError)

  API_URL = 'https://api-3t.%s/nvp' % ENV.fetch('EXCO_HOST')
  WEB_URL = 'https://www.%s' % ENV.fetch('EXCO_HOST')

  CREDENTIALS = {
    'USER'      => ENV.fetch('EXCO_USERNAME'),
    'PWD'       => ENV.fetch('EXCO_PASSWORD'),
    'SIGNATURE' => ENV.fetch('EXCO_SIGNATURE'),
    'VERSION'   => ENV.fetch('EXCO_VERSION', '86.0')
  }

  def self.set_express_checkout(
    amount: nil,
    invoice: nil,
    description: nil,
    return_url: nil,
    cancel_url: nil)

    payload = CREDENTIALS.merge(
      'METHOD' => 'SetExpressCheckout',
      'RETURNURL' => return_url,
      'CANCELURL' => cancel_url,
      'REQCONFIRMSHIPPING' => 0,
      'NOSHIPPING' => 1,
      'ALLOWNOTE' => 0,
      'PAYMENTREQUEST_0_PAYMENTACTION' => 'Sale',
      'PAYMENTREQUEST_0_AMT' => amount,
      'PAYMENTREQUEST_0_INVNUM' => invoice,
      'L_BILLINGTYPE0' => 'RecurringPayments',
      'L_BILLINGAGREEMENTDESCRIPTION0' => description
    )

    response = process(request('POST', payload))

    return checkout_url(response['TOKEN'])
  end

  def self.get_express_checkout_details(token)
    payload = CREDENTIALS.merge(
      'METHOD' => 'GetExpressCheckoutDetails',
      'TOKEN' => token
    )

    process(request('POST', payload))
  end

  def self.do_express_checkout(
    token: nil,
    amount: nil,
    payer_id: nil)

    payload = CREDENTIALS.merge(
      'METHOD' => 'DoExpressCheckoutPayment',
      'TOKEN' => token,
      'PAYERID' => payer_id,
      'PAYMENTACTION' => 'Sale',
      'AMT' => amount
    )

    process(request('POST', payload))
  end

  def self.create_recurring_payments_profile(
    token: nil,
    payer_id: nil,
    amount: nil,
    description: nil,
    profile_start_date: Date.today + 30,
    billing_period: 'Month',
    billing_frequency: '1')

    payload = CREDENTIALS.merge(
      'METHOD' => 'CreateRecurringPaymentsProfile',
      'TOKEN' => token,
      'PAYERID' => payer_id,
      'AMT' => amount,
      'PROFILESTARTDATE' => profile_start_date.strftime('%Y-%m-%dT00:00:00Z'),
      'BILLINGPERIOD' => billing_period,
      'BILLINGFREQUENCY' => billing_frequency,
      'DESC' => description
    )

    process(request('POST', payload))
  end

  def self.cancel_recurring_payments_profile(profile_id)
    payload = CREDENTIALS.merge(
      'METHOD' => 'ManageRecurringPaymentsProfileStatus',
      'PROFILEID' => profile_id,
      'NOTE' => 'Subscription canceled',
      'ACTION' => 'Cancel'
    )

    process(request('POST', payload))
  end

private
  def self.checkout_url(token)
    '%s/cgi-bin/webscr?cmd=_express-checkout&token=%s' % [WEB_URL, token]
  end

  def self.process(response)
    if response['ACK'] == 'Success'
      return response
    else
      raise Error, response
    end
  end

  def self.request(method, data)
    out, err, res = Open3.capture3('curl -X%s -d @- %s' % [method, API_URL],
                                   stdin_data: URI.encode_www_form(data))

    if res.success?
      Hash[URI.decode_www_form(out)]
    else
      raise err
    end
  end
end
