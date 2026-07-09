class StripeConfig {
  /// The Stripe Publishable Key.
  /// Never put the Secret Key here!
  static const String publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );
}
