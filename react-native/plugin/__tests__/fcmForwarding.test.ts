import { afterAll, describe, expect, it } from '@jest/globals';
import fs from 'fs';
import path from 'path';

import {
  forwardingLibrary,
  serviceName,
  serviceSource,
  withSallaPushFcmForwarding,
} from '../src/android/fcmForwarding';
import { appConfig, runMod, tempProject } from './mods';

const FILE = path.join(
  'android',
  'app',
  'src',
  'main',
  'java',
  'sa',
  'salla',
  'example',
  'SallaPushMessagingService.kt'
);
const roots: string[] = [];

afterAll(() => {
  for (const root of roots) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

function project(
  dependencies: Record<string, string>,
  files: Record<string, string> = {}
): string {
  const root = tempProject({
    'package.json': JSON.stringify({ dependencies }),
    ...files,
  });
  roots.push(root);
  return root;
}

const app = () => appConfig({ android: { package: 'sa.salla.example' } });

describe('forwardingLibrary', () => {
  it('finds the one library that owns FCM', () => {
    expect(forwardingLibrary({}, new Set(['expo', 'expo-notifications']))).toBe(
      'expo-notifications'
    );
    expect(
      forwardingLibrary(
        { fcmForwarding: 'auto' },
        new Set([
          '@react-native-firebase/app',
          '@react-native-firebase/messaging',
        ])
      )
    ).toBe('@react-native-firebase/messaging');
    expect(forwardingLibrary({}, new Set(['expo']))).toBeUndefined();
  });

  it('throws when both libraries are there, asking to pick one', () => {
    expect(() =>
      forwardingLibrary(
        {},
        new Set(['expo-notifications', '@react-native-firebase/messaging'])
      )
    ).toThrow(
      '@salla.sa/mobile-push-react-native: the app has both expo-notifications and @react-native-firebase/messaging, and only one FCM service gets the messages. Set android.fcmForwarding to the library that receives FCM in this app.'
    );
  });

  it('takes the library the app names, or none', () => {
    const both = new Set([
      'expo-notifications',
      '@react-native-firebase/messaging',
    ]);

    expect(
      forwardingLibrary({ fcmForwarding: 'expo-notifications' }, both)
    ).toBe('expo-notifications');
    expect(
      forwardingLibrary(
        { fcmForwarding: '@react-native-firebase/messaging' },
        new Set()
      )
    ).toBe('@react-native-firebase/messaging');
    expect(forwardingLibrary({ fcmForwarding: 'none' }, both)).toBeUndefined();
  });
});

describe('serviceSource', () => {
  it.each(['expo-notifications', '@react-native-firebase/messaging'] as const)(
    "extends %s's service and calls SallaPush first",
    (library) => {
      expect(serviceSource('sa.salla.example', library)).toMatchSnapshot();
    }
  );
});

describe('serviceSource with a Kotlin keyword in the package', () => {
  it('quotes the keyword, as Expo does in its own Kotlin files', () => {
    expect(
      serviceSource('in.example.shop', 'expo-notifications').split('\n')[1]
    ).toBe('package `in`.example.shop');
  });
});

describe('serviceName', () => {
  it("is the class in the app's package", () => {
    expect(serviceName(app())).toBe(
      'sa.salla.example.SallaPushMessagingService'
    );
    expect(() => serviceName(appConfig())).toThrow(
      '@salla.sa/mobile-push-react-native: forwarding FCM to SallaPush needs android.package in the app config.'
    );
  });
});

describe('withSallaPushFcmForwarding', () => {
  it("writes the service into the app's package folder", async () => {
    const root = project({ 'expo-notifications': '57.0.10' });

    await runMod(
      withSallaPushFcmForwarding(app(), {}),
      'android',
      'dangerous',
      undefined,
      root
    );

    expect(fs.readFileSync(path.join(root, FILE), 'utf8')).toBe(
      serviceSource('sa.salla.example', 'expo-notifications')
    );
  });

  it("deletes an earlier prebuild's service once nothing is forwarded", async () => {
    const root = project(
      {},
      {
        [FILE]: serviceSource(
          'sa.salla.example',
          '@react-native-firebase/messaging'
        ),
      }
    );

    await runMod(
      withSallaPushFcmForwarding(app(), {}),
      'android',
      'dangerous',
      undefined,
      root
    );

    expect(fs.existsSync(path.join(root, FILE))).toBe(false);
  });

  it("replaces an earlier prebuild's service", async () => {
    const root = project(
      { 'expo-notifications': '57.0.10' },
      {
        [FILE]: serviceSource(
          'sa.salla.example',
          '@react-native-firebase/messaging'
        ),
      }
    );

    await runMod(
      withSallaPushFcmForwarding(app(), {}),
      'android',
      'dangerous',
      undefined,
      root
    );

    expect(fs.readFileSync(path.join(root, FILE), 'utf8')).toBe(
      serviceSource('sa.salla.example', 'expo-notifications')
    );
  });

  const own = 'package sa.salla.example\n\nclass SallaPushMessagingService\n';

  it("leaves a file of the app's own alone", async () => {
    const root = project({}, { [FILE]: own });

    await runMod(
      withSallaPushFcmForwarding(app(), { fcmForwarding: 'none' }),
      'android',
      'dangerous',
      undefined,
      root
    );

    expect(fs.readFileSync(path.join(root, FILE), 'utf8')).toBe(own);
  });

  it("never overwrites a file of the app's own to forward", async () => {
    const root = project({ 'expo-notifications': '57.0.10' }, { [FILE]: own });

    await expect(
      runMod(
        withSallaPushFcmForwarding(app(), {}),
        'android',
        'dangerous',
        undefined,
        root
      )
    ).rejects.toThrow(
      `@salla.sa/mobile-push-react-native: ${FILE} is the app's own file, not the plugin's, so the plugin doesn't overwrite it. Set android.fcmForwarding to 'none' to keep it, or delete it to use the plugin's.`
    );
    expect(fs.readFileSync(path.join(root, FILE), 'utf8')).toBe(own);
  });

  it('needs android.package only to forward', async () => {
    await expect(
      runMod(
        withSallaPushFcmForwarding(appConfig(), {}),
        'android',
        'dangerous',
        undefined,
        project({})
      )
    ).resolves.toBeDefined();
    await expect(
      runMod(
        withSallaPushFcmForwarding(appConfig(), {}),
        'android',
        'dangerous',
        undefined,
        project({ 'expo-notifications': '57.0.10' })
      )
    ).rejects.toThrow('needs android.package in the app config.');
  });
});
