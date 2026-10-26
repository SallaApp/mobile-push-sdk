import 'package:flutter/widgets.dart';
// snippet:import
import 'package:mobile_push/mobile_push.dart';
// end-snippet

import 'stand_ins.dart';

/// The README's routing and click listener snippets, analyzed so that they
/// stay correct; the example never runs them.
void routingSnippet(AppRouter router) {
  // snippet:route
  void route(SallaPushNotification notification) {
    final int? productId = notification.getString('type') == 'product'
        ? notification.getInt('id')
        : null;
    final String? url = notification.launchUrl;
    if (productId != null) {
      router.showProduct(productId);
    } else if (url != null) {
      router.openUrl(url);
    }
  }
  // end-snippet

  // snippet:click-listener
  SallaPush.notifications.onClick.listen(
    (SallaPushClickEvent event) => route(event.notification),
  );
  // end-snippet
}

// The README's login and logout snippet, analyzed so that it stays correct;
// the example never runs it.
// snippet:login-logout
Future<void> customerDidSignIn(String customerId, String customerToken) async {
  await SallaPush.login(externalId: customerId, identityToken: customerToken);
}

Future<void> customerDidSignOut() async {
  await SallaPush.logout();
}
// end-snippet

/// The README's permission snippet, analyzed so that it stays correct; the
/// example never runs it.
Future<bool> permissionSnippet() async {
  // snippet:request-permission
  final bool granted = await SallaPush.notifications.requestPermission(
    fallbackToSettings: true,
  );
  // end-snippet
  return granted;
}

/// The README's tag snippet, analyzed so that it stays correct; the example
/// never runs it.
Future<void> tagsSnippet({required int total, required int items}) async {
  // snippet:tags
  await SallaPush.user.addTags(<String, String>{
    'cart_items': '$items',
    'total_cart_amount': '$total',
  });
  // end-snippet
}

/// The README's push subscription snippet, analyzed so that it stays correct;
/// the example never runs it.
void subscriptionSnippet(SettingsScreen settings) {
  // snippet:subscription-listener
  SallaPush.user.pushSubscription.onChange.listen((state) {
    settings.showDevice(state.current.id, optedIn: state.current.optedIn);
  });
  // end-snippet
}

/// The README's log handler snippet, analyzed so that it stays correct; the
/// example never runs it.
Future<void> logHandlerSnippet(Telemetry telemetry) async {
  // snippet:log-handler
  await SallaPush.debug.setLogHandler(SallaPushLogLevel.error, (entry) {
    telemetry.report('sallapush', entry.code, entry.message, entry.metadata);
  });
  // end-snippet
}

/// The setup guide's snippet for apps that know the app id only at run time,
/// analyzed so that it stays correct; the example never runs it.
Future<void> initializeSnippet(
  String appId, {
  required bool requiresConsent,
}) async {
  // snippet:initialize
  // At every launch. Consent-gated apps require consent first.
  if (requiresConsent) {
    await SallaPush.setConsentRequired(true);
  }
  await SallaPush.initialize(appId);
  // end-snippet
}

/// The README's foreground snippet, analyzed so that it stays correct; the
/// example never runs it.
Future<void> chatListenerSnippet(String chatId) async {
  // snippet:chat-listener
  // While a chat screen shows, its chat's notifications stay hidden.
  final chatListener = SallaPush.notifications.onWillDisplay.listen((event) {
    if (event.notification.getString('chat_id') == chatId) {
      event.preventDefault(); // Before any await.
    }
  });
  // When the chat screen goes:
  await chatListener.cancel();
  // end-snippet
}

// snippet:launch-tap
/// Routes SallaPush taps once the app can show a screen: the tap that
/// launched the app arrives before the first frame, when there is no
/// navigator yet.
final class NotificationTaps {
  /// Routes with [route].
  NotificationTaps(this.route);

  /// Shows the screen of a tapped notification.
  final void Function(SallaPushNotification notification) route;

  final List<SallaPushNotification> _pending = <SallaPushNotification>[];
  bool _ready = false;

  /// In main(), before runApp.
  void listen() {
    SallaPush.notifications.onClick.listen((SallaPushClickEvent event) {
      if (_ready) {
        route(event.notification);
      } else {
        _pending.add(event.notification);
      }
    });
  }

  /// In the root widget's initState.
  void routeAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ready = true;
      for (final SallaPushNotification notification in _pending) {
        route(notification);
      }
      _pending.clear();
    });
  }
}
// end-snippet
