import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';
import { WarningAggregator, type InfoPlist } from 'expo/config-plugins';
import fs from 'fs';

import withSallaPush from '../src';
import {
  pluginOptions,
  projectDependencies,
  validateProps,
} from '../src/validate';
import { appConfig, fixture, modsOf, runMod, tempProject } from './mods';

const roots: string[] = [];
let warn: jest.SpiedFunction<typeof WarningAggregator.addWarningIOS>;

/** A project with the SDK 57 Podfile and a package.json listing these packages. */
function project(dependencies: Record<string, Record<string, string>>): string {
  const root = tempProject({
    'package.json': JSON.stringify(dependencies),
    'ios/Podfile': fixture('sdk-57/Podfile'),
  });
  roots.push(root);
  return root;
}

beforeEach(() => {
  warn = jest
    .spyOn(WarningAggregator, 'addWarningIOS')
    .mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
});

afterAll(() => {
  for (const root of roots) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

describe('validateProps', () => {
  it('takes no options', () => {
    const none = { ios: {}, android: {} };

    expect(validateProps(appConfig(), undefined)).toEqual(none);
    expect(validateProps(appConfig(), null)).toEqual(none);
    expect(validateProps(appConfig(), {})).toEqual(none);
    expect(validateProps(appConfig(), { ios: null, android: null })).toEqual(
      none
    );
  });

  it('returns the options without null or undefined values', () => {
    expect(
      validateProps(appConfig(), {
        ios: {
          appId: 'st_42_ios',
          logLevel: null,
          appGroup: undefined,
          openLaunchUrls: false,
          apnsEnvironment: 'production',
        },
        android: {
          appId: 'st_42_android',
          smallIcon: null,
          displayCompatPayloads: false,
          fcmForwarding: '@react-native-firebase/messaging',
        },
      })
    ).toEqual({
      ios: {
        appId: 'st_42_ios',
        openLaunchUrls: false,
        apnsEnvironment: 'production',
      },
      android: {
        appId: 'st_42_android',
        displayCompatPayloads: false,
        fcmForwarding: '@react-native-firebase/messaging',
      },
    });
  });

  it.each(['st_42_ios', 'A-b_9', 'x'.repeat(64)])(
    'accepts the app id %s',
    (appId) => {
      expect(validateProps(appConfig(), { ios: { appId } }).ios.appId).toBe(
        appId
      );
    }
  );

  it.each([
    '',
    'st 42',
    'st.42',
    'x'.repeat(65),
    '$(SALLAPUSH_APP_ID)',
    'متجر_42',
  ])('rejects the app id "%s"', (appId) => {
    expect(() => validateProps(appConfig(), { ios: { appId } })).toThrow(
      `@salla.sa/mobile-push-react-native: ios.appId ${JSON.stringify(appId)} is not a SallaPush app id, which has 1 to 64 letters, digits, "_" or "-". Use the app id the Salla team gave you.`
    );
  });

  it('applies the same rule to android.appId', () => {
    expect(
      validateProps(appConfig(), { android: { appId: 'st_42_android' } })
        .android.appId
    ).toBe('st_42_android');
    expect(() =>
      validateProps(appConfig(), { android: { appId: 'st 42' } })
    ).toThrow(
      '@salla.sa/mobile-push-react-native: android.appId "st 42" is not a SallaPush app id, which has 1 to 64 letters, digits, "_" or "-". Use the app id the Salla team gave you.'
    );
  });

  it.each([
    './assets/notification-icon.png',
    'assets/Icon.PNG',
    '@drawable/ic_notification',
  ])('accepts the small icon %s', (smallIcon) => {
    expect(
      validateProps(appConfig(), { android: { smallIcon } }).android.smallIcon
    ).toBe(smallIcon);
  });

  it.each([
    './assets/notification-icon.jpg',
    './assets/icon.xml',
    '@drawable/Ic-Notification',
    '@mipmap/ic_launcher',
  ])('rejects the small icon %s', (smallIcon) => {
    expect(() =>
      validateProps(appConfig(), { android: { smallIcon } })
    ).toThrow(
      `@salla.sa/mobile-push-react-native: android.smallIcon ${JSON.stringify(smallIcon)} must be a .png file, such as "./assets/notification-icon.png", or a drawable, such as "@drawable/ic_notification".`
    );
  });

  it('rejects unknown options, naming the known ones', () => {
    expect(() => validateProps(appConfig(), { iOS: {} })).toThrow(
      '@salla.sa/mobile-push-react-native: unknown option iOS. The options are ios, android.'
    );
    expect(() =>
      validateProps(appConfig(), { android: { package: 'sa.salla.example' } })
    ).toThrow(
      '@salla.sa/mobile-push-react-native: unknown option android.package. The android options are appId, smallIcon, defaultChannelId, defaultChannelName, openLaunchUrls, requiresUserConsent, clearTagsOnLogout, autoClearBadge, autoUpdateBadge, appVersion, logLevel, displayCompatPayloads, fcmForwarding.'
    );
    expect(() =>
      validateProps(appConfig(), { ios: { requireUserConsent: true } })
    ).toThrow(
      '@salla.sa/mobile-push-react-native: unknown option ios.requireUserConsent. The ios options are appId, mode, appGroup, openLaunchUrls, requiresUserConsent, clearTagsOnLogout, autoClearBadge, autoUpdateBadge, registerForRemoteNotificationsOnInit, apnsEnvironment, appVersion, logLevel, notificationServiceExtension, developmentTeam.'
    );
  });

  it.each([
    [{ openLaunchUrls: 'yes' }, 'ios.openLaunchUrls must be true or false.'],
    [{ appVersion: 2 }, 'ios.appVersion must be a string.'],
    [
      { notificationServiceExtension: 'no' },
      'ios.notificationServiceExtension must be true or false.',
    ],
    [{ developmentTeam: 12345 }, 'ios.developmentTeam must be a string.'],
    [
      { mode: 'staging' },
      'ios.mode must be one of "development", "production".',
    ],
    [
      { logLevel: 'warning' },
      'ios.logLevel must be one of "off", "error", "warn", "info", "debug", "verbose".',
    ],
    [
      { apnsEnvironment: 'dev' },
      'ios.apnsEnvironment must be one of "automatic", "sandbox", "production".',
    ],
  ])('rejects the mistyped option %j', (ios, message) => {
    expect(() => validateProps(appConfig(), { ios })).toThrow(
      `@salla.sa/mobile-push-react-native: ${message}`
    );
  });

  it.each([
    [
      { displayCompatPayloads: 'false' },
      'android.displayCompatPayloads must be true or false.',
    ],
    [{ defaultChannelName: 7 }, 'android.defaultChannelName must be a string.'],
    [
      { fcmForwarding: 'firebase' },
      'android.fcmForwarding must be one of "auto", "none", "expo-notifications", "@react-native-firebase/messaging".',
    ],
  ])('rejects the mistyped Android option %j', (android, message) => {
    expect(() => validateProps(appConfig(), { android })).toThrow(
      `@salla.sa/mobile-push-react-native: ${message}`
    );
  });

  it.each<['ios' | 'android', 'autoClearBadge' | 'autoUpdateBadge']>([
    ['ios', 'autoClearBadge'],
    ['ios', 'autoUpdateBadge'],
    ['android', 'autoClearBadge'],
    ['android', 'autoUpdateBadge'],
  ])('takes only true or false for %s.%s', (platform, option) => {
    for (const value of [true, false]) {
      expect(
        validateProps(appConfig(), { [platform]: { [option]: value } })[
          platform
        ]
      ).toEqual({ [option]: value });
    }
    expect(() =>
      validateProps(appConfig(), { [platform]: { [option]: 'yes' } })
    ).toThrow(
      `@salla.sa/mobile-push-react-native: ${platform}.${option} must be true or false.`
    );
  });

  it('rejects options that are not objects', () => {
    expect(() => validateProps(appConfig(), 'st_42_ios')).toThrow(
      '@salla.sa/mobile-push-react-native: the plugin options must be an object, such as { "ios": { "appId": "…" } }.'
    );
    expect(() => validateProps(appConfig(), { ios: ['st_42_ios'] })).toThrow(
      '@salla.sa/mobile-push-react-native: ios must be an object.'
    );
  });

  it.each([
    ['newArchEnabled', { newArchEnabled: false }],
    ['ios.newArchEnabled', { ios: { newArchEnabled: false } }],
    ['android.newArchEnabled', { android: { newArchEnabled: false } }],
  ])('rejects %s: false', (name, config) => {
    expect(() => validateProps(appConfig(config), {})).toThrow(
      `@salla.sa/mobile-push-react-native: the SallaPush module needs React Native's New Architecture, and the app config sets ${name}: false. Remove that setting.`
    );
  });

  it("rejects onesignal-expo-plugin unless SallaPush's extension is off", () => {
    const message =
      '@salla.sa/mobile-push-react-native: onesignal-expo-plugin adds its own Notification Service Extension, and an app has only one. Set ios.notificationServiceExtension to false, and call SallaPush first in that extension (see the README).';

    expect(() =>
      validateProps(appConfig({ plugins: ['onesignal-expo-plugin'] }), {})
    ).toThrow(message);
    expect(() =>
      validateProps(
        appConfig({
          plugins: [['onesignal-expo-plugin', { mode: 'development' }]],
        }),
        { ios: { notificationServiceExtension: true } }
      )
    ).toThrow(message);
    expect(
      validateProps(appConfig({ plugins: ['onesignal-expo-plugin'] }), {
        ios: { notificationServiceExtension: false },
      })
    ).toEqual({ ios: { notificationServiceExtension: false }, android: {} });
  });

  it('accepts newArchEnabled: true', () => {
    expect(() =>
      validateProps(
        appConfig({ newArchEnabled: true, ios: { newArchEnabled: true } }),
        {}
      )
    ).not.toThrow();
  });
});

describe('the plugin', () => {
  it('registers the iOS and Android mods after checking the options', () => {
    const config = withSallaPush(appConfig(), {
      ios: { appId: 'st_42_ios', notificationServiceExtension: false },
      android: { appId: 'st_42_android' },
    });

    expect(Object.keys(modsOf(config, 'ios')).sort()).toEqual([
      'appDelegate',
      'dangerous',
      'entitlements',
      'infoPlist',
    ]);
    expect(Object.keys(modsOf(config, 'android')).sort()).toEqual([
      'dangerous',
      'manifest',
      'strings',
    ]);
    expect(() =>
      withSallaPush(appConfig(), { ios: { appId: 'not an id' } })
    ).toThrow('ios.appId "not an id" is not a SallaPush app id');
  });

  it('runs once when the app config lists it twice', () => {
    const once = withSallaPush(appConfig(), { ios: { appId: 'st_42_ios' } });
    const mods = modsOf(once, 'ios');

    const twice = withSallaPush(once, { ios: { appId: 'st_42_ios' } });

    expect(modsOf(twice, 'ios')).toEqual(mods);
  });

  it('warns that SallaPush starts from JavaScript on iOS without ios.appId', async () => {
    await runMod<InfoPlist>(withSallaPush(appConfig()), 'ios', 'infoPlist', {});
    await runMod<InfoPlist>(
      withSallaPush(appConfig(), { ios: { appId: 'st_42_ios' } }),
      'ios',
      'infoPlist',
      {}
    );

    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '@salla.sa/mobile-push-react-native',
      'ios.appId is not set, so on iOS SallaPush starts only when JavaScript calls SallaPush.initialize.'
    );
  });
});

describe('the React Native Firebase warning', () => {
  const firebase = {
    dependencies: { '@react-native-firebase/messaging': '24.0.0' },
  };
  const text =
    '@react-native-firebase/messaging needs dynamic frameworks: add the expo-build-properties plugin with { "ios": { "useFrameworks": "dynamic" } }.';

  async function prebuild(
    dependencies: Record<string, Record<string, string>>,
    plugins: unknown[] = []
  ) {
    const config = withSallaPush(appConfig({ plugins }), {
      ios: { appId: 'st_42_ios' },
    });
    await runMod(config, 'ios', 'dangerous', undefined, project(dependencies));
  }

  it('warns when the app has React Native Firebase without dynamic frameworks', async () => {
    await prebuild(firebase);
    await prebuild(firebase, [
      ['expo-build-properties', { ios: { useFrameworks: 'static' } }],
    ]);
    await prebuild({
      devDependencies: { '@react-native-firebase/messaging': '24.0.0' },
    });

    expect(warn).toHaveBeenCalledTimes(3);
    expect(warn).toHaveBeenCalledWith(
      '@salla.sa/mobile-push-react-native',
      text
    );
  });

  it('is quiet with dynamic frameworks, or without React Native Firebase', async () => {
    await prebuild(firebase, [
      'expo-notifications',
      ['expo-build-properties', { ios: { useFrameworks: 'dynamic' } }],
    ]);
    await prebuild({
      dependencies: { '@react-native-firebase/app': '24.0.0' },
    });

    expect(warn).not.toHaveBeenCalled();
  });
});

describe('pluginOptions', () => {
  it('reads the options another plugin has in the app config', () => {
    const config = appConfig({
      plugins: [
        'expo-notifications',
        ['expo-router'],
        ['expo-build-properties', { ios: { useFrameworks: 'dynamic' } }],
      ],
    });

    expect(pluginOptions(config, 'expo-notifications')).toEqual({});
    expect(pluginOptions(config, 'expo-router')).toEqual({});
    expect(pluginOptions(config, 'expo-build-properties')).toEqual({
      ios: { useFrameworks: 'dynamic' },
    });
    expect(pluginOptions(config, 'expo-camera')).toBeUndefined();
    expect(pluginOptions(appConfig(), 'expo-camera')).toBeUndefined();
  });
});

describe('projectDependencies', () => {
  it('lists the dependencies and devDependencies of package.json', () => {
    expect([
      ...projectDependencies(
        project({
          dependencies: { expo: '57.0.28' },
          devDependencies: { typescript: '6.0.3' },
        })
      ),
    ]).toEqual(['expo', 'typescript']);
    expect(projectDependencies(project({})).size).toBe(0);
  });
});
