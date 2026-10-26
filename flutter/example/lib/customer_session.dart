import 'package:mobile_push/mobile_push.dart';

/// A signed-in customer: the Salla customer id and the customer token the app
/// received from Salla when the customer signed in.
final class Customer {
  /// Creates a customer.
  const Customer({required this.id, required this.identityToken});

  /// The Salla customer id, SallaPush's external id.
  final String id;

  /// The identity token that proves [id].
  final String identityToken;
}

/// The example's stand-in for an app's session.
///
/// An app keeps its session its own way; SallaPush only needs to hear of every
/// change. The example keeps it in memory: a sign-in lasts until the app ends,
/// and the session at launch comes from the dart-defines
/// SALLAPUSH_CUSTOMER_ID and SALLAPUSH_CUSTOMER_TOKEN.
final class CustomerSession {
  /// A session with [customer] signed in, or signed out without one.
  CustomerSession([this._customer]);

  /// The session at launch: the customer of the dart-defines, else signed out.
  factory CustomerSession.atLaunch() {
    const String id = String.fromEnvironment('SALLAPUSH_CUSTOMER_ID');
    const String identityToken = String.fromEnvironment(
      'SALLAPUSH_CUSTOMER_TOKEN',
    );
    return CustomerSession(
      id.isEmpty || identityToken.isEmpty
          ? null
          : const Customer(id: id, identityToken: identityToken),
    );
  }

  Customer? _customer;

  /// The signed-in customer; null while signed out.
  Customer? get customer => _customer;

  int _change = 0;

  /// Tells SallaPush who is signed in, as an app does at every launch, before
  /// any tag call: the customer logs in, else SallaPush logs out.
  Future<void> restore() async {
    final Customer? customer = _customer;
    if (customer == null) {
      await SallaPush.logout();
      return;
    }
    await SallaPush.login(
      externalId: customer.id,
      identityToken: customer.identityToken,
    );
  }

  Future<void> signIn(Customer customer) async {
    final Customer? previous = _customer;
    _customer = customer;
    final int change = ++_change;
    // Another customer: log the previous one out first.
    if (previous != null && previous.id != customer.id) {
      await SallaPush.logout();
      // A later sign-in or sign-out replaced this one meanwhile.
      if (change != _change) return;
    }
    await SallaPush.login(
      externalId: customer.id,
      identityToken: customer.identityToken,
    );
  }

  Future<void> signOut() async {
    _customer = null;
    _change++;
    await SallaPush.logout();
  }
}
