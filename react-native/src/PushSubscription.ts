import NativeRNSallaPush from './NativeRNSallaPush';
import {
  SubscriptionHub,
  addListener,
  removeListener,
} from './internal/EventHub';
import type { SallaPushSubscriptionNamespace } from './types';

const hubs = { change: new SubscriptionHub() };

export const PushSubscription: SallaPushSubscriptionNamespace = {
  getId: () => NativeRNSallaPush.getPushSubscriptionId(),
  getToken: () => NativeRNSallaPush.getPushSubscriptionToken(),
  getOptedIn: () => NativeRNSallaPush.getPushSubscriptionOptedIn(),
  optIn: () => NativeRNSallaPush.optIn(),
  optOut: () => NativeRNSallaPush.optOut(),
  addEventListener: (event: unknown, listener: unknown) =>
    addListener(
      'SallaPush.User.pushSubscription.addEventListener',
      hubs,
      event,
      listener
    ),
  removeEventListener: (event: unknown, listener: unknown) =>
    removeListener(
      'SallaPush.User.pushSubscription.removeEventListener',
      hubs,
      event,
      listener
    ),
};
