import NativeRNSallaPush from './NativeRNSallaPush';
import { PushSubscription } from './PushSubscription';
import { EventHub, addListener, removeListener } from './internal/EventHub';
import { loginFailure, userChange } from './internal/mapping';
import { array, nullable, record, string, valid } from './internal/validate';
import type { SallaPushUserNamespace } from './types';

const hubs = {
  change: new EventHub({
    kind: 'user',
    name: "SallaPush.User 'change' listener",
    subscribe: (handler) => NativeRNSallaPush.onUserChange(handler),
    map: userChange,
  }),
  loginFailure: new EventHub({
    kind: 'loginFailure',
    name: "SallaPush.User 'loginFailure' listener",
    subscribe: (handler) => NativeRNSallaPush.onLoginFailure(handler),
    map: loginFailure,
  }),
};

// The entries of addTags and removeTags go to native unchecked: native skips and logs the ones that aren't strings.
export const User: SallaPushUserNamespace = {
  pushSubscription: PushSubscription,
  getExternalId: () => NativeRNSallaPush.getExternalId(),
  isLoggedIn: () => NativeRNSallaPush.isLoggedIn(),
  addTag(key, value) {
    if (
      valid('SallaPush.User.addTag', {
        key: [key, string],
        value: [value, string],
      })
    ) {
      NativeRNSallaPush.addTag(key, value);
    }
  },
  addTags(tags) {
    if (valid('SallaPush.User.addTags', { tags: [tags, record] })) {
      NativeRNSallaPush.addTags(tags);
    }
  },
  removeTag(key) {
    if (valid('SallaPush.User.removeTag', { key: [key, string] })) {
      NativeRNSallaPush.removeTag(key);
    }
  },
  removeTags(keys) {
    if (valid('SallaPush.User.removeTags', { keys: [keys, array] })) {
      NativeRNSallaPush.removeTags(keys);
    }
  },
  getTags: () => NativeRNSallaPush.getTags() as Promise<Record<string, string>>,
  setLanguage(language) {
    if (
      valid('SallaPush.User.setLanguage', {
        language: [language, nullable(string)],
      })
    ) {
      NativeRNSallaPush.setLanguage(language);
    }
  },
  addEventListener: (event: unknown, listener: unknown) =>
    addListener('SallaPush.User.addEventListener', hubs, event, listener),
  removeEventListener: (event: unknown, listener: unknown) =>
    removeListener('SallaPush.User.removeEventListener', hubs, event, listener),
};
