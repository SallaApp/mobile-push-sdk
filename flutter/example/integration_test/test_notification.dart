// The test notification of the smoke tests and of verify.sh smoke's
// hot-restart check: the native SDKs' test message, which the example's test
// hooks (ios/Runner/TestHooks.swift, MainActivity.kt) deliver to SallaPush the
// way each platform delivers a push.

import 'dart:io';

import 'package:flutter/services.dart';

/// The native SDKs' test message, with a boolean key added.
const Map<String, String> testData = <String, String>{
  'sp_v': '1',
  'sp_id': 'msg_5a11a90001',
  'sp_url': 'https://example.com/products/42',
  'type': 'product',
  'id': '42',
  'in_stock': 'true',
};

/// The test message as each platform delivers it: the APNs payload on iOS,
/// FCM data on Android.
final Map<String, Object> testPayload = Platform.isIOS
    ? <String, Object>{
        'aps': <String, Object>{
          'alert': <String, String>{
            'title': 'SallaPush test',
            'body': 'A native SallaPush notification',
          },
          'sound': 'default',
        },
        ...testData,
      }
    : <String, Object>{
        'sp_title': 'SallaPush test',
        'sp_body': 'A native SallaPush notification',
        ...testData,
      };

/// Delivers [testPayload]: on iOS as a local notification, answering null; on
/// Android through SallaPush's FCM handling, answering whether SallaPush
/// handled it.
Future<Object?> deliverTestNotification() => const MethodChannel(
  'example/test_hooks',
).invokeMethod<Object?>('deliverTestNotification', testPayload);
