import { SallaPush } from '@salla.sa/mobile-push-react-native';

// The example's sign-in and sign-out: the customer's id as Salla knows it, and the token Salla issued for that id.

export function customerDidSignIn(
  externalId: string,
  identityToken: string
): void {
  // snippet:login-logout
  // After the customer signs in:
  SallaPush.login(externalId, identityToken);
  // end-snippet
}

export function customerDidSignOut(): void {
  // snippet:login-logout
  // After the customer signs out:
  SallaPush.logout();
  // end-snippet
}
