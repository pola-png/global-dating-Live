class FlutterwaveConfig {
  // Flutterwave public key (already set to your live or test key)
  static const String publicKey = 'FLWPUBK-f73ff7ab57d77478bc5fa3c6ba387108-X';

  // Flutterwave currency (e.g. USD, NGN, GHS, etc.)
  static const String currency = 'USD';

  // Redirect URL can be any valid URL; mostly used on web.
  static const String redirectUrl = 'https://globaldatingchat.example.com/payment-complete';

  // Set to false in production
  static const bool isTestMode = true;

  // Optional: hosted payment links per coin package.
  // Create payment links in your Flutterwave dashboard and paste them here.
  static const Map<int, String> hostedPaymentLinks = {
    60: 'https://flutterwave.com/pay/rujbo8xc4whw',
    400: 'https://flutterwave.com/pay/qu6rfqknnphx',
    1000: 'https://flutterwave.com/pay/hizvj4r8s3pm',
    5000: 'https://flutterwave.com/pay/hikdcwkglncz',
    10000: 'https://flutterwave.com/pay/sadj3pd9qk1c',
  };

  // Optional: hosted payment link for fast matchmaking ($50).
  static const String fastMatchPaymentLink =
      'https://flutterwave.com/pay/s1mhxoyxoeok';
}
