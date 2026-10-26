import {
  afterAll,
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';
import {
  AndroidConfig,
  WarningAggregator,
  XML,
  withAndroidManifest,
  type ConfigPlugin,
} from 'expo/config-plugins';
import fs from 'fs';
import os from 'os';
import path from 'path';

import {
  setManifest,
  setStrings,
  withSallaPushAndroidManifest,
  withSallaPushStrings,
} from '../src/android/manifest';
import type { AndroidProps } from '../src/validate';
import { appConfig, runMod, tempProject } from './mods';

type AndroidManifest = AndroidConfig.Manifest.AndroidManifest;
type ResourceXML = AndroidConfig.Resources.ResourceXML;

const SERVICE = 'sa.salla.example.SallaPushMessagingService';
const roots: string[] = [];
let warn: jest.SpiedFunction<typeof WarningAggregator.addWarningAndroid>;

beforeEach(() => {
  warn = jest
    .spyOn(WarningAggregator, 'addWarningAndroid')
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

function manifest(sdk = 'sdk-57'): Promise<AndroidManifest> {
  return AndroidConfig.Manifest.readAndroidManifestAsync(
    path.join(__dirname, '..', '__fixtures__', sdk, 'AndroidManifest.xml')
  );
}

function application(result: AndroidManifest) {
  return AndroidConfig.Manifest.getMainApplicationOrThrow(result);
}

/** The meta-data of the main application, as name → attributes. */
function metaData(result: AndroidManifest) {
  return Object.fromEntries(
    (application(result)['meta-data'] ?? []).map(({ $ }) => {
      const { 'android:name': name, ...attributes } = $;
      return [name, attributes];
    })
  );
}

async function written(result: AndroidManifest): Promise<string> {
  const file = path.join(
    fs.mkdtempSync(path.join(os.tmpdir(), 'sallapush-manifest-')),
    'AndroidManifest.xml'
  );
  roots.push(path.dirname(file));
  await AndroidConfig.Manifest.writeAndroidManifestAsync(file, result);
  return fs.readFileSync(file, 'utf8');
}

const ALL: AndroidProps = {
  appId: 'st_42_android',
  smallIcon: './assets/notification-icon.png',
  defaultChannelId: 'news',
  defaultChannelName: 'News',
  openLaunchUrls: true,
  requiresUserConsent: true,
  clearTagsOnLogout: false,
  autoClearBadge: false,
  autoUpdateBadge: true,
  appVersion: '2.1.0',
  logLevel: 'debug',
  displayCompatPayloads: false,
  fcmForwarding: 'expo-notifications',
};

describe.each(['sdk-54', 'sdk-57'])('the Expo %s manifest', (sdk) => {
  it('gets the meta-data of every option, the icon and the service', async () => {
    const result = setManifest(await manifest(sdk), ALL, SERVICE);

    expect(metaData(result)).toEqual({
      'com.salla.push.APP_ID': { 'android:value': '@string/sallapush_app_id' },
      'com.salla.push.OPEN_LAUNCH_URLS': { 'android:value': 'true' },
      'com.salla.push.REQUIRES_USER_CONSENT': { 'android:value': 'true' },
      'com.salla.push.CLEAR_TAGS_ON_LOGOUT': { 'android:value': 'false' },
      'com.salla.push.AUTO_CLEAR_BADGE': { 'android:value': 'false' },
      'com.salla.push.AUTO_UPDATE_BADGE': { 'android:value': 'true' },
      'com.salla.push.APP_VERSION': {
        'android:value': '@string/sallapush_app_version',
      },
      'com.salla.push.DISPLAY_COMPAT_PAYLOADS': {
        'android:value': 'false',
      },
      'com.salla.push.LOG_LEVEL': { 'android:value': 'debug' },
      'com.salla.push.default_channel_id': {
        'android:value': '@string/sallapush_default_channel_id',
      },
      'com.salla.push.default_channel_name': {
        'android:value': '@string/sallapush_default_channel_name',
      },
      'com.salla.push.default_notification_icon': {
        'android:resource': '@drawable/sallapush_small_icon',
      },
    });
    expect(await written(result)).toContain(
      [
        `    <service android:name="${SERVICE}" android:exported="false">`,
        '      <intent-filter android:priority="1">',
        '        <action android:name="com.google.firebase.MESSAGING_EVENT"/>',
        '      </intent-filter>',
        '      <meta-data android:name="sa.salla.sallapush.reactnative.GENERATED" android:value="true"/>',
        '    </service>',
        '  </application>',
      ].join('\n')
    );
  });

  it('is unchanged by a second run', async () => {
    const once = await written(setManifest(await manifest(sdk), ALL, SERVICE));
    const twice = await written(
      setManifest(setManifest(await manifest(sdk), ALL, SERVICE), ALL, SERVICE)
    );

    expect(twice).toBe(once);
  });
});

describe('setManifest', () => {
  it('writes nothing for absent options, and no icon without smallIcon', async () => {
    const original = await written(await manifest());

    expect(await written(setManifest(await manifest(), {}, undefined))).toBe(
      original
    );
  });

  it('replaces an element of the same name instead of adding one', async () => {
    const existing = await manifest();
    const app = application(existing);
    app['meta-data'] = [
      {
        $: {
          'android:name': 'com.salla.push.LOG_LEVEL',
          'android:value': 'off',
        },
      },
      {
        $: {
          'android:name': 'com.salla.push.default_notification_icon',
          'android:value': 'ic_old',
        },
      },
    ];

    const result = setManifest(
      existing,
      { logLevel: 'warn', smallIcon: '@drawable/ic_notification' },
      undefined
    );

    expect(metaData(result)).toEqual({
      'com.salla.push.LOG_LEVEL': { 'android:value': 'warn' },
      'com.salla.push.default_notification_icon': {
        'android:resource': '@drawable/ic_notification',
      },
    });
  });

  it("points the icon at the app's drawable when smallIcon names one", async () => {
    const result = setManifest(
      await manifest(),
      { smallIcon: '@drawable/ic_notification' },
      undefined
    );

    expect(
      metaData(result)['com.salla.push.default_notification_icon']
    ).toEqual({ 'android:resource': '@drawable/ic_notification' });
  });

  it("removes an earlier prebuild's meta-data of a string option no longer given, and keeps the app's own", async () => {
    const existing = setManifest(
      await manifest(),
      { appVersion: '2.10', defaultChannelId: 'news', logLevel: 'info' },
      undefined
    );
    application(existing)['meta-data']?.push({
      $: {
        'android:name': 'com.salla.push.APP_ID',
        'android:value': 'st_42_android',
      },
    });

    const result = setManifest(existing, {}, undefined);

    expect(metaData(result)).toEqual({
      'com.salla.push.LOG_LEVEL': { 'android:value': 'info' },
      'com.salla.push.APP_ID': { 'android:value': 'st_42_android' },
    });
  });

  it("removes an earlier prebuild's service once nothing is forwarded, and keeps the app's others", async () => {
    const existing = setManifest(await manifest(), {}, SERVICE);
    application(existing).service?.push({
      $: { 'android:name': '.OtherService', 'android:exported': 'false' },
    });

    const result = setManifest(existing, {}, undefined);

    expect(
      application(result).service?.map(({ $ }) => $['android:name'])
    ).toEqual(['.OtherService']);
    expect(
      application(setManifest(await manifest(), {}, undefined))
    ).not.toHaveProperty('service');
  });

  it("replaces an earlier prebuild's service, found by its marker, and keeps the app's others", async () => {
    const existing = setManifest(
      await manifest(),
      {},
      'sa.salla.old.SallaPushMessagingService'
    );
    application(existing).service?.push(
      ownService('com.other.SallaPushMessagingService')
    );

    const result = setManifest(existing, {}, SERVICE);

    expect(
      application(result).service?.map(({ $ }) => $['android:name'])
    ).toEqual(['com.other.SallaPushMessagingService', SERVICE]);
  });

  it.each(['.SallaPushMessagingService', SERVICE])(
    "keeps the app's own %s once nothing is forwarded",
    async (name) => {
      const existing = await manifest();
      application(existing).service = [ownService(name)];

      const result = setManifest(existing, {}, undefined);

      expect(application(result).service).toEqual([ownService(name)]);
    }
  );

  it.each(['.SallaPushMessagingService', SERVICE, 'SallaPushMessagingService'])(
    "doesn't replace the app's own %s with its forwarding service",
    async (name) => {
      const existing = await manifest();
      application(existing).service = [ownService(name)];

      expect(() => setManifest(existing, {}, SERVICE)).toThrow(
        `@salla.sa/mobile-push-react-native: AndroidManifest.xml declares the app's own ${name}, not the plugin's, so the plugin doesn't replace it. Set android.fcmForwarding to 'none' to keep it, or remove it to use the plugin's.`
      );
    }
  );
});

/** The forwarding service of the README, as an app's own config plugin declares it. */
function ownService(name: string) {
  return {
    '$': { 'android:name': name, 'android:exported': 'false' as const },
    'intent-filter': [
      {
        $: { 'android:priority': '1' } as Record<string, string>,
        action: [
          { $: { 'android:name': 'com.google.firebase.MESSAGING_EVENT' } },
        ],
      },
    ],
  };
}

/** The strings.xml of an app, as Expo's strings mod reads it. */
function strings(): ResourceXML {
  return {
    resources: { string: [{ $: { name: 'app_name' }, _: 'HelloWorld' }] },
  };
}

/** Writes `result` as Expo's strings mod does, then reads it back as the next prebuild does. */
async function rewritten(result: ResourceXML): Promise<[string, ResourceXML]> {
  const file = path.join(
    fs.mkdtempSync(path.join(os.tmpdir(), 'sallapush-strings-')),
    'strings.xml'
  );
  roots.push(path.dirname(file));
  await XML.writeXMLAsync({ path: file, xml: result });
  return [
    fs.readFileSync(file, 'utf8'),
    await AndroidConfig.Resources.readResourcesXMLAsync({ path: file }),
  ];
}

describe('setStrings', () => {
  it("writes each string option as an untranslatable string, escaped as AAPT reads it, next to the app's", async () => {
    const [xml] = await rewritten(
      setStrings(strings(), {
        appId: 'st_42_android',
        appVersion: '2.10',
        defaultChannelId: '1001',
        defaultChannelName: "@Today's offers ",
        logLevel: 'debug',
        requiresUserConsent: true,
      })
    );

    expect(xml.split('\n')).toEqual([
      '<resources>',
      '  <string name="app_name">HelloWorld</string>',
      '  <string name="sallapush_app_id" translatable="false">st_42_android</string>',
      '  <string name="sallapush_app_version" translatable="false">2.10</string>',
      '  <string name="sallapush_default_channel_id" translatable="false">1001</string>',
      '  <string name="sallapush_default_channel_name" translatable="false">"\\@Today\\\'s offers "</string>',
      '</resources>',
    ]);
  });

  it('removes the strings of the options no longer given', () => {
    const before = setStrings(strings(), {
      appVersion: '2.10',
      defaultChannelName: 'News',
    });

    const after = setStrings(before, { appVersion: '2.10' });

    expect(after.resources.string?.map(({ $ }) => $.name)).toEqual([
      'app_name',
      'sallapush_app_version',
    ]);
  });

  it('is unchanged by a second prebuild', async () => {
    const props: AndroidProps = {
      appVersion: '2.10',
      defaultChannelName: "@Today's offers ",
    };
    const [once, read] = await rewritten(setStrings(strings(), props));

    const [twice] = await rewritten(setStrings(read, props));

    expect(twice).toBe(once);
  });

  it('edits strings.xml through the strings mod', async () => {
    const { modResults } = await runMod(
      withSallaPushStrings(appConfig(), { appVersion: '2.10' }),
      'android',
      'strings',
      strings()
    );

    expect(modResults.resources.string?.[1]).toEqual({
      $: { name: 'sallapush_app_version', translatable: 'false' },
      _: '2.10',
    });
  });
});

describe('withSallaPushAndroidManifest', () => {
  function project(dependencies: Record<string, string>): string {
    const root = tempProject({
      'package.json': JSON.stringify({ dependencies }),
    });
    roots.push(root);
    return root;
  }

  const config = (extra: Record<string, unknown> = {}) =>
    appConfig({
      android: {
        package: 'sa.salla.example',
        googleServicesFile: './google-services.json',
      },
      ...extra,
    });

  it('adds the forwarding service when another library owns FCM', async () => {
    const { modResults } = await runMod(
      withSallaPushAndroidManifest(config(), { appId: 'st_42_android' }),
      'android',
      'manifest',
      await manifest(),
      project({ '@react-native-firebase/messaging': '24.0.0' })
    );

    expect(
      application(modResults).service?.map(({ $ }) => $['android:name'])
    ).toEqual([SERVICE]);
  });

  it("keeps the service that the app's own plugin adds first, with fcmForwarding 'none'", async () => {
    const withOwnService: ConfigPlugin = (appConfiguration) =>
      withAndroidManifest(appConfiguration, (mod) => {
        application(mod.modResults).service = [
          ownService('.SallaPushMessagingService'),
        ];
        return mod;
      });

    const { modResults } = await runMod(
      withOwnService(
        withSallaPushAndroidManifest(config(), {
          appId: 'st_42_android',
          fcmForwarding: 'none',
        })
      ),
      'android',
      'manifest',
      await manifest(),
      project({ 'expo-notifications': '57.0.10' })
    );

    expect(application(modResults).service).toEqual([
      ownService('.SallaPushMessagingService'),
    ]);
  });

  it('adds no service when FCM stays with SallaPush', async () => {
    const { modResults } = await runMod(
      withSallaPushAndroidManifest(config(), {
        fcmForwarding: 'auto',
        smallIcon: '@drawable/ic_notification',
      }),
      'android',
      'manifest',
      await manifest(),
      project({ expo: '57.0.28' })
    );

    expect(application(modResults)).not.toHaveProperty('service');
  });

  it('warns about a missing app id, Firebase configuration and small icon', async () => {
    await runMod(
      withSallaPushAndroidManifest(appConfig({ android: {} }), {}),
      'android',
      'manifest',
      await manifest(),
      project({})
    );

    expect(warn.mock.calls).toEqual([
      [
        '@salla.sa/mobile-push-react-native',
        'android.appId is not set, so on Android SallaPush starts only when JavaScript calls SallaPush.initialize, and processes that FCM starts run without it.',
      ],
      [
        '@salla.sa/mobile-push-react-native',
        'android.googleServicesFile is not set, so Firebase has no configuration and SallaPush gets no FCM token (token.firebase_missing).',
      ],
      [
        '@salla.sa/mobile-push-react-native',
        "android.smallIcon is not set, so SallaPush uses Firebase's default_notification_icon when the app sets one, else its own bell (display.default_icon).",
      ],
    ]);
  });

  it('names the options that SallaPush reads only with android.appId', async () => {
    await runMod(
      withSallaPushAndroidManifest(config(), {
        smallIcon: '@drawable/ic_notification',
        requiresUserConsent: true,
        clearTagsOnLogout: false,
        autoClearBadge: false,
        autoUpdateBadge: false,
        logLevel: 'info',
        displayCompatPayloads: false,
      }),
      'android',
      'manifest',
      await manifest(),
      project({})
    );

    expect(warn.mock.calls).toEqual([
      [
        '@salla.sa/mobile-push-react-native',
        "android.appId is not set, so on Android SallaPush starts only when JavaScript calls SallaPush.initialize, and processes that FCM starts run without it. Without it, SallaPush doesn't read android.requiresUserConsent, android.clearTagsOnLogout, android.autoClearBadge, android.autoUpdateBadge; pass them to SallaPush.initialize instead, as requiresUserConsent, clearTagsOnLogout, autoClearBadge, autoUpdateBadge.",
      ],
    ]);
  });

  it('is quiet when the app id, Firebase configuration and small icon are set', async () => {
    await runMod(
      withSallaPushAndroidManifest(config(), {
        appId: 'st_42_android',
        smallIcon: '@drawable/ic_notification',
      }),
      'android',
      'manifest',
      await manifest(),
      project({})
    );

    expect(warn).not.toHaveBeenCalled();
  });
});
