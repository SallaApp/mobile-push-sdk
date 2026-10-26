import { Platform } from 'react-native';
import {
  SallaPush,
  SallaPushIOSPermissionStatus,
  SallaPushLogLevel,
  type SallaPushEventSubscription,
  type SallaPushLogEntry,
  type SallaPushNotification,
  type SallaPushUserChangedState,
} from '@salla.sa/mobile-push-react-native';
import { eventLog, followLogs } from './eventLog';

/** The app id of the smoke configuration. */
export const SMOKE_APP_ID = 'example_smoke';

const CUSTOMER_ID = 'smoke-customer';
const APNS_TOKEN = '0123456789abcdef'.repeat(4);
const EVENT_TIMEOUT_MS = 10_000;
const LEVELS: readonly string[] = Object.values(SallaPushLogLevel);
const PERMISSION_STATUSES: readonly string[] = Object.values(
  SallaPushIOSPermissionStatus
);

// The smoke notification: ios/TestPayloads/native.apns and android/TestPayloads/native.json.
const SMOKE_NOTIFICATION = {
  notificationId: 'msg_5a11a90001',
  title: 'SallaPush test',
  body: 'A native SallaPush notification',
  launchUrl: 'https://example.com/products/42',
  source: 'native',
  additionalData: { type: 'product', id: '42' },
};
const SMOKE_NOTIFICATION_DATA = {
  sp_v: '1',
  sp_id: SMOKE_NOTIFICATION.notificationId,
  ...SMOKE_NOTIFICATION.additionalData,
};

/**
 * The smoke tests' self-test, run at launch when SallaPush started with the smoke app id. It calls every API member,
 * logs `SALLAPUSH_SELFTEST {"passed":n,"failed":m,"failures":[…],"skipped":[…],"willDisplay":…}`, and, when it waits
 * for the smoke notification, logs `SALLAPUSH_SELFTEST_WILL_DISPLAY {"ok":true}` once it arrives in the foreground.
 */
export async function startSelfTest(): Promise<void> {
  if ((await SallaPush.getAppId()) !== SMOKE_APP_ID) {
    return;
  }
  const report = new Report();
  try {
    await checkFacade(report);
    await checkNotifications(report);
    await checkUser(report);
    await checkPushSubscription(report);
    await checkDebug(report);
    await checkListeners(report);
  } catch (error) {
    report.fail('the self-test', String(error));
  }
  const willDisplay = (await waitForSmokeNotification())
    ? 'waiting'
    : 'skipped: notifications are not allowed';
  print('SALLAPUSH_SELFTEST', report.result(willDisplay));
}

async function checkFacade(report: Report): Promise<void> {
  report.equal(
    'SallaPush.isInitialized()',
    await SallaPush.isInitialized(),
    true
  );
  report.equal(
    'SallaPush.getAppId()',
    await SallaPush.getAppId(),
    SMOKE_APP_ID
  );
  const version = await SallaPush.getSdkVersion();
  report.check(
    'SallaPush.getSdkVersion()',
    /^\d+\.\d+\.\d+/.test(version),
    version
  );
  SallaPush.initialize(SMOKE_APP_ID);
  report.equal(
    'SallaPush.getAppId() after initialize() with the same app id',
    await SallaPush.getAppId(),
    SMOKE_APP_ID
  );
  SallaPush.setConsentRequired(false);
  SallaPush.setConsentGiven(true);
  report.equal(
    'SallaPush.isInitialized() after the consent calls',
    await SallaPush.isInitialized(),
    true
  );
}

async function checkNotifications(report: Report): Promise<void> {
  const notifications = SallaPush.Notifications;
  const ios = Platform.OS === 'ios';
  const allowedBefore = await notifications.getPermission();
  const granted = nextEvent<boolean>(
    (listener) => notifications.addEventListener('permissionChange', listener),
    (allowed) => allowed
  );
  // iOS: quiet notifications without a prompt, so the smoke notification can arrive in the foreground.
  const provisional = await notifications.registerForProvisionalAuthorization();
  report.check(
    'Notifications.registerForProvisionalAuthorization()',
    ios ? typeof provisional === 'boolean' : provisional === false,
    provisional
  );
  const status = await notifications.getPermissionStatus();
  report.check(
    'Notifications.getPermissionStatus()',
    ios ? isOneOf(PERMISSION_STATUSES, status) : status === null,
    status
  );
  const allowed = await notifications.getPermission();
  report.check(
    'Notifications.getPermission()',
    typeof allowed === 'boolean',
    allowed
  );
  if (!allowedBefore && allowed) {
    report.check("Notifications 'permissionChange' event", await granted);
  }
  const canRequest = await notifications.canRequestPermission();
  report.check(
    'Notifications.canRequestPermission()',
    typeof canRequest === 'boolean',
    canRequest
  );
  if (allowed && (!ios || status === SallaPushIOSPermissionStatus.Authorized)) {
    report.equal(
      'Notifications.requestPermission() while allowed',
      await notifications.requestPermission(false),
      true
    );
  } else {
    report.skip('Notifications.requestPermission()', 'it would show a prompt');
  }
  notifications.refreshPermission();
  notifications.registerForRemoteNotifications();
  notifications.forwardApnsToken(APNS_TOKEN);
  notifications.clearAll();
  notifications.removeNotification(1);
  report.equal(
    'Notifications.isSallaPushNotification() for the smoke notification',
    await notifications.isSallaPushNotification(SMOKE_NOTIFICATION_DATA),
    true
  );
  report.equal(
    'Notifications.isSallaPushNotification() for another payload',
    await notifications.isSallaPushNotification({ other: 'payload' }),
    false
  );
  const opened = await notifications.trackOpened({
    push_ref: SMOKE_NOTIFICATION.notificationId,
  });
  report.check(
    'Notifications.trackOpened()',
    ios ? opened === false : typeof opened === 'boolean',
    opened
  );
  SallaPush.Migration.setDisplayCompatPayloads(true);
}

async function checkUser(report: Report): Promise<void> {
  const user = SallaPush.User;
  const loggedIn = nextEvent<SallaPushUserChangedState>(
    (listener) => user.addEventListener('change', listener),
    (state) => state.current.externalId === CUSTOMER_ID
  );
  SallaPush.login(CUSTOMER_ID, 'smoke-identity-token');
  report.equal(
    'User.getExternalId() after login()',
    await user.getExternalId(),
    CUSTOMER_ID
  );
  report.equal(
    'User.isLoggedIn() after login()',
    await user.isLoggedIn(),
    true
  );
  report.check("User 'change' event after login()", await loggedIn);

  user.addTag('Smoke_Key', 'value');
  user.addTags({ Smoke_Second: '2', smoke_third: '3' });
  const tags = await user.getTags();
  report.equal(
    "User.getTags() after addTag('Smoke_Key', 'value')",
    tags.smoke_key,
    'value'
  );
  report.check(
    'User.getTags() after addTags()',
    tags.smoke_second === '2' && tags.smoke_third === '3',
    tags
  );
  user.removeTag('smoke_key');
  user.removeTags(['smoke_second', 'smoke_third']);
  const remaining = await user.getTags();
  report.check(
    'User.getTags() after removeTag() and removeTags()',
    ['smoke_key', 'smoke_second', 'smoke_third'].every(
      (key) => !(key in remaining)
    ),
    remaining
  );
  user.setLanguage('ar');
  user.setLanguage(null);

  SallaPush.logout();
  report.equal(
    'User.getExternalId() after logout()',
    await user.getExternalId(),
    null
  );
  report.equal(
    'User.isLoggedIn() after logout()',
    await user.isLoggedIn(),
    false
  );
}

async function checkPushSubscription(report: Report): Promise<void> {
  const subscription = SallaPush.User.pushSubscription;
  const id = await subscription.getId();
  report.check(
    'pushSubscription.getId()',
    id === null || typeof id === 'string',
    id
  );
  const token = await subscription.getToken();
  // The token is private: a failure names its type only.
  report.check(
    'pushSubscription.getToken()',
    token === null || typeof token === 'string',
    typeof token
  );
  const optedIn = await subscription.getOptedIn();
  report.check(
    'pushSubscription.getOptedIn()',
    typeof optedIn === 'boolean',
    optedIn
  );
  subscription.optOut();
  report.equal(
    'pushSubscription.getOptedIn() after optOut()',
    await subscription.getOptedIn(),
    false
  );
  subscription.optIn();
}

async function checkDebug(report: Report): Promise<void> {
  const debug = SallaPush.Debug;
  const level = await debug.getLogLevel();
  report.check('Debug.getLogLevel()', isOneOf(LEVELS, level), level);
  debug.setLogLevel(SallaPushLogLevel.Verbose);
  report.equal(
    "Debug.getLogLevel() after setLogLevel('verbose')",
    await debug.getLogLevel(),
    SallaPushLogLevel.Verbose
  );
  debug.setLogLevel(level);

  const invalidKey = nextLogEntry('tags.invalid_key');
  SallaPush.User.addTag('not a key!', 'value');
  const entry = await invalidKey;
  report.check(
    'Debug.setLogHandler() gets the entry of an invalid tag key',
    entry !== null &&
      entry.level === SallaPushLogLevel.Warn &&
      typeof entry.timestamp === 'number',
    entry
  );
  debug.setLogHandler(SallaPushLogLevel.Verbose, null);
  followLogs(eventLog.logLevel());
}

/**
 * A listener removed between two events must get the first and miss the second, which another listener still gets:
 * login() and logout() make user 'change' events here, and waitForSmokeNotification checks a removed will-display
 * listener. The other events need a tap, a permission change, a refused login or a registered device, which the smoke
 * configuration doesn't have, so their listeners are only added and removed, and reported as skipped.
 */
async function checkListeners(report: Report): Promise<void> {
  const user = SallaPush.User;
  const states: SallaPushUserChangedState[] = [];
  const subscription = user.addEventListener('change', (state) => {
    states.push(state);
  });
  const loggedIn = nextEvent<SallaPushUserChangedState>(
    (listener) => user.addEventListener('change', listener),
    (state) => state.current.isLoggedIn
  );
  SallaPush.login(CUSTOMER_ID, 'smoke-identity-token');
  report.check(
    "User 'change' listener gets the event of login() while added",
    (await loggedIn) && states.some((state) => state.current.isLoggedIn),
    states
  );
  subscription.remove();
  const received = states.length;
  const loggedOut = nextEvent<SallaPushUserChangedState>(
    (listener) => user.addEventListener('change', listener),
    (state) => !state.current.isLoggedIn
  );
  SallaPush.logout();
  report.check(
    "User 'change' listener misses the event of logout() once removed",
    (await loggedOut) && states.length === received,
    states.slice(received)
  );

  const ignore = () => {};
  const unobserved: Array<[string, string, () => SallaPushEventSubscription]> =
    [
      [
        "Notifications 'click' listener",
        'its event needs a tap',
        () => SallaPush.Notifications.addEventListener('click', ignore),
      ],
      [
        "Notifications 'permissionChange' listener",
        'its event needs a permission change',
        () =>
          SallaPush.Notifications.addEventListener('permissionChange', ignore),
      ],
      [
        "User 'loginFailure' listener",
        'its event needs a login the server refuses',
        () => user.addEventListener('loginFailure', ignore),
      ],
      [
        "User.pushSubscription 'change' listener",
        'its event needs a registered device',
        () => user.pushSubscription.addEventListener('change', ignore),
      ],
    ];
  for (const [name, reason, add] of unobserved) {
    add().remove();
    report.skip(name, reason);
  }
}

/**
 * Listens for the smoke notification while the app is in the foreground; false when notifications can't be shown. A
 * listener removed before it arrives must not get it.
 */
async function waitForSmokeNotification(): Promise<boolean> {
  if (!(await SallaPush.Notifications.getPermission())) {
    return false;
  }
  let removedListenerRan = false;
  SallaPush.Notifications.addEventListener('foregroundWillDisplay', () => {
    removedListenerRan = true;
  }).remove();
  const subscription = SallaPush.Notifications.addEventListener(
    'foregroundWillDisplay',
    (event) => {
      subscription.remove();
      const failures = smokeNotificationFailures(event.notification);
      if (removedListenerRan) {
        failures.push(
          "a 'foregroundWillDisplay' listener removed before the notification got it"
        );
      }
      print(
        'SALLAPUSH_SELFTEST_WILL_DISPLAY',
        failures.length === 0 ? { ok: true } : { ok: false, failures }
      );
    }
  );
  // Calls reach native in order: once this resolves, the native listener is registered.
  await SallaPush.isInitialized();
  return true;
}

function smokeNotificationFailures(
  notification: SallaPushNotification
): string[] {
  const failures: string[] = [];
  const expect = (name: string, actual: unknown, expected: unknown) => {
    if (!Object.is(actual, expected)) {
      failures.push(
        `${name}: got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`
      );
    }
  };
  expect(
    'notificationId',
    notification.notificationId,
    SMOKE_NOTIFICATION.notificationId
  );
  expect('title', notification.title, SMOKE_NOTIFICATION.title);
  expect('body', notification.body, SMOKE_NOTIFICATION.body);
  expect('launchUrl', notification.launchUrl, SMOKE_NOTIFICATION.launchUrl);
  expect('source', notification.source, SMOKE_NOTIFICATION.source);
  for (const [key, value] of Object.entries(
    SMOKE_NOTIFICATION.additionalData
  )) {
    expect(`additionalData.${key}`, notification.additionalData[key], value);
  }
  expect("getString('type')", notification.getString('type'), 'product');
  expect("getString('id')", notification.getString('id'), '42');
  expect("getInt('id')", notification.getInt('id'), 42);
  expect("getInt('type')", notification.getInt('type'), null);
  expect("getBool('id')", notification.getBool('id'), null);
  expect(
    "getNumber('id')",
    notification.getNumber('id'),
    Platform.OS === 'ios' ? 42 : null
  );
  return failures;
}

/** Resolves true when `listen` delivers a matching value within the timeout, then stops listening. */
function nextEvent<Value>(
  listen: (listener: (value: Value) => void) => SallaPushEventSubscription,
  matches: (value: Value) => boolean
): Promise<boolean> {
  return new Promise((resolve) => {
    const finish = (arrived: boolean) => {
      clearTimeout(timer);
      subscription.remove();
      resolve(arrived);
    };
    const timer = setTimeout(() => finish(false), EVENT_TIMEOUT_MS);
    const subscription = listen((value) => {
      if (matches(value)) {
        finish(true);
      }
    });
  });
}

/** Sets a log handler at verbose and resolves with the first entry with `code`, or null after the timeout. */
function nextLogEntry(code: string): Promise<SallaPushLogEntry | null> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), EVENT_TIMEOUT_MS);
    SallaPush.Debug.setLogHandler(SallaPushLogLevel.Verbose, (entry) => {
      if (entry.code === code) {
        clearTimeout(timer);
        resolve(entry);
      }
    });
  });
}

function isOneOf(values: readonly string[], value: unknown): boolean {
  return typeof value === 'string' && values.includes(value);
}

function print(marker: string, value: object): void {
  console.info(`${marker} ${JSON.stringify(value)}`);
}

class Report {
  private passed = 0;
  private readonly failures: string[] = [];
  private readonly skipped: string[] = [];

  equal(name: string, actual: unknown, expected: unknown): void {
    this.check(name, Object.is(actual, expected), actual);
  }

  check(name: string, passed: boolean, actual?: unknown): void {
    if (passed) {
      this.passed += 1;
    } else {
      this.fail(name, `got ${JSON.stringify(actual)}`);
    }
  }

  fail(name: string, reason: string): void {
    this.failures.push(`${name}: ${reason}`);
  }

  skip(name: string, reason: string): void {
    this.skipped.push(`${name}: ${reason}`);
  }

  result(willDisplay: string): object {
    return {
      passed: this.passed,
      failed: this.failures.length,
      failures: this.failures,
      skipped: this.skipped,
      willDisplay,
    };
  }
}
