import NativeRNSallaPush from './NativeRNSallaPush';
import { EventHub, addListener, removeListener } from './internal/EventHub';
import {
  clickEvent,
  permissionChange,
  willDisplayEvent,
} from './internal/mapping';
import {
  boolean,
  integer,
  nullable,
  optional,
  record,
  string,
  valid,
} from './internal/validate';
import type {
  SallaPushIOSPermissionStatus,
  SallaPushNotificationsNamespace,
} from './types';

const hubs = {
  click: new EventHub({
    kind: 'click',
    name: "SallaPush.Notifications 'click' listener",
    subscribe: (handler) => NativeRNSallaPush.onClick(handler),
    map: clickEvent,
  }),
  // Native holds each notification until JavaScript decides: shown, unless a listener prevented it.
  foregroundWillDisplay: new EventHub({
    kind: 'willDisplay',
    name: "SallaPush.Notifications 'foregroundWillDisplay' listener",
    subscribe: (handler) => NativeRNSallaPush.onWillDisplay(handler),
    map: willDisplayEvent,
    decide: (event, payload) => {
      if (!event.isPrevented) {
        NativeRNSallaPush.displayNotification(payload.handle);
      }
    },
  }),
  permissionChange: new EventHub({
    kind: 'permission',
    name: "SallaPush.Notifications 'permissionChange' listener",
    subscribe: (handler) => NativeRNSallaPush.onPermissionChange(handler),
    map: permissionChange,
  }),
};

// A dropped promise-returning call resolves false, the neutral value of a platform-only call.
export const Notifications: SallaPushNotificationsNamespace = {
  getPermission: () => NativeRNSallaPush.getPermission(),
  canRequestPermission: () => NativeRNSallaPush.canRequestPermission(),
  getPermissionStatus: () =>
    NativeRNSallaPush.getPermissionStatus() as Promise<SallaPushIOSPermissionStatus | null>,
  requestPermission(fallbackToSettings) {
    if (
      !valid('SallaPush.Notifications.requestPermission', {
        fallbackToSettings: [fallbackToSettings, optional(boolean)],
      })
    ) {
      return Promise.resolve(false);
    }
    return NativeRNSallaPush.requestPermission(fallbackToSettings ?? false);
  },
  registerForProvisionalAuthorization: () =>
    NativeRNSallaPush.registerForProvisionalAuthorization(),
  refreshPermission: () => NativeRNSallaPush.refreshPermission(),
  registerForRemoteNotifications: () =>
    NativeRNSallaPush.registerForRemoteNotifications(),
  forwardApnsToken(apnsToken) {
    if (
      valid('SallaPush.Notifications.forwardApnsToken', {
        apnsToken: [apnsToken, string],
      })
    ) {
      NativeRNSallaPush.forwardApnsToken(apnsToken);
    }
  },
  clearAll: () => NativeRNSallaPush.clearAll(),
  removeNotification(androidNotificationId) {
    if (
      valid('SallaPush.Notifications.removeNotification', {
        androidNotificationId: [androidNotificationId, integer],
      })
    ) {
      NativeRNSallaPush.removeNotification(androidNotificationId);
    }
  },
  isSallaPushNotification(payload) {
    if (
      !valid('SallaPush.Notifications.isSallaPushNotification', {
        payload: [payload, record],
      })
    ) {
      return Promise.resolve(false);
    }
    return NativeRNSallaPush.isSallaPushNotification(payload);
  },
  trackOpened(additionalData) {
    if (
      !valid('SallaPush.Notifications.trackOpened', {
        additionalData: [additionalData, nullable(record)],
      })
    ) {
      return Promise.resolve(false);
    }
    return NativeRNSallaPush.trackOpened(additionalData);
  },
  addEventListener: (event: unknown, listener: unknown) =>
    addListener(
      'SallaPush.Notifications.addEventListener',
      hubs,
      event,
      listener
    ),
  removeEventListener: (event: unknown, listener: unknown) =>
    removeListener(
      'SallaPush.Notifications.removeEventListener',
      hubs,
      event,
      listener
    ),
};
