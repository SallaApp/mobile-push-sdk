import { jest } from '@jest/globals';

import type { Spec } from '../NativeRNSallaPush';

/** An emitter subscription; each emitter mock records the handler it was given and returns a new one. */
const subscription = () => ({ remove: jest.fn<() => void>() });

/** The TurboModule for Jest: every method records its calls, and getters resolve native's defaults. */
const NativeRNSallaPush = {
  initWithAppId: jest.fn<Spec['initWithAppId']>(),
  isInitialized: jest.fn<Spec['isInitialized']>(() => Promise.resolve(false)),
  getAppId: jest.fn<Spec['getAppId']>(() => Promise.resolve(null)),
  getSdkVersion: jest.fn<Spec['getSdkVersion']>(() => Promise.resolve('1.1.0')),
  setConsentRequired: jest.fn<Spec['setConsentRequired']>(),
  setConsentGiven: jest.fn<Spec['setConsentGiven']>(),
  login: jest.fn<Spec['login']>(),
  logout: jest.fn<Spec['logout']>(),

  getExternalId: jest.fn<Spec['getExternalId']>(() => Promise.resolve(null)),
  isLoggedIn: jest.fn<Spec['isLoggedIn']>(() => Promise.resolve(false)),
  addTag: jest.fn<Spec['addTag']>(),
  addTags: jest.fn<Spec['addTags']>(),
  removeTag: jest.fn<Spec['removeTag']>(),
  removeTags: jest.fn<Spec['removeTags']>(),
  getTags: jest.fn<Spec['getTags']>(() => Promise.resolve({})),
  setLanguage: jest.fn<Spec['setLanguage']>(),

  getPushSubscriptionId: jest.fn<Spec['getPushSubscriptionId']>(() =>
    Promise.resolve(null)
  ),
  getPushSubscriptionToken: jest.fn<Spec['getPushSubscriptionToken']>(() =>
    Promise.resolve(null)
  ),
  getPushSubscriptionOptedIn: jest.fn<Spec['getPushSubscriptionOptedIn']>(() =>
    Promise.resolve(false)
  ),
  optIn: jest.fn<Spec['optIn']>(),
  optOut: jest.fn<Spec['optOut']>(),
  addPushSubscriptionListener: jest.fn<Spec['addPushSubscriptionListener']>(),
  removePushSubscriptionListener:
    jest.fn<Spec['removePushSubscriptionListener']>(),

  getPermission: jest.fn<Spec['getPermission']>(() => Promise.resolve(false)),
  canRequestPermission: jest.fn<Spec['canRequestPermission']>(() =>
    Promise.resolve(false)
  ),
  getPermissionStatus: jest.fn<Spec['getPermissionStatus']>(() =>
    Promise.resolve(null)
  ),
  requestPermission: jest.fn<Spec['requestPermission']>(() =>
    Promise.resolve(false)
  ),
  registerForProvisionalAuthorization: jest.fn<
    Spec['registerForProvisionalAuthorization']
  >(() => Promise.resolve(false)),
  refreshPermission: jest.fn<Spec['refreshPermission']>(),
  registerForRemoteNotifications:
    jest.fn<Spec['registerForRemoteNotifications']>(),
  forwardApnsToken: jest.fn<Spec['forwardApnsToken']>(),
  clearAll: jest.fn<Spec['clearAll']>(),
  removeNotification: jest.fn<Spec['removeNotification']>(),
  isSallaPushNotification: jest.fn<Spec['isSallaPushNotification']>(() =>
    Promise.resolve(false)
  ),
  trackOpened: jest.fn<Spec['trackOpened']>(() => Promise.resolve(false)),
  displayNotification: jest.fn<Spec['displayNotification']>(),

  setDisplayCompatPayloads: jest.fn<Spec['setDisplayCompatPayloads']>(),

  getLogLevel: jest.fn<Spec['getLogLevel']>(() => Promise.resolve('warn')),
  setLogLevel: jest.fn<Spec['setLogLevel']>(),
  setLogHandlerLevel: jest.fn<Spec['setLogHandlerLevel']>(),

  startEvents: jest.fn<Spec['startEvents']>(),
  stopEvents: jest.fn<Spec['stopEvents']>(),

  onClick: jest.fn<Spec['onClick']>(subscription),
  onWillDisplay: jest.fn<Spec['onWillDisplay']>(subscription),
  onPermissionChange: jest.fn<Spec['onPermissionChange']>(subscription),
  onUserChange: jest.fn<Spec['onUserChange']>(subscription),
  onLoginFailure: jest.fn<Spec['onLoginFailure']>(subscription),
  onPushSubscriptionChange:
    jest.fn<Spec['onPushSubscriptionChange']>(subscription),
  onLog: jest.fn<Spec['onLog']>(subscription),
};

export default NativeRNSallaPush;
