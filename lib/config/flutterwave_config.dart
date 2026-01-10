class FlutterwaveConfig {
  // Flutterwave V3 Live API keys
  static const String publicKey = 'FLWPUBK-c36a5c7a117e43cf5f1769805afb76e3-X';
  static const String secretKey = 'FLWSECK-71477d13d71d86257bbaf38a3acac3e2-19b3dece247vt-X';
  static const String encryptionKey = '71477d13d71dfc8b82c0a236';

  // Flutterwave currency (e.g. USD, NGN, GHS, etc.)
  static const String currency = 'USD';

  // Set to false in production
  static const bool isTestMode = false;

  // Note: Using standard API flow instead of hosted payment links for better mobile integration
}
