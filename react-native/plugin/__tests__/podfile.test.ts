import { afterAll, describe, expect, it } from '@jest/globals';
import fs from 'fs';
import path from 'path';

import { SALLAPUSH_IOS_VERSION } from '../src/constants';
import { addPods, withSallaPushPodfile } from '../src/ios/podfile';
import { appConfig, fixture, runMod, tempProject } from './mods';

const PODS = [
  '  # @generated begin sallapush-pods - expo prebuild (DO NOT MODIFY)',
  `  pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'`,
  `  pod 'SallaPush', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'`,
  '  # @generated end sallapush-pods',
].join('\n');

const LINKAGE = [
  "use_frameworks! :linkage => podfile_properties['ios.useFrameworks'].to_sym if podfile_properties['ios.useFrameworks']",
  "use_frameworks! :linkage => ENV['USE_FRAMEWORKS'].to_sym if ENV['USE_FRAMEWORKS']",
];

const NSE_PODS = [
  '# @generated begin sallapush-nse - expo prebuild (DO NOT MODIFY)',
  "target 'SallaPushNotificationService' do",
  ...LINKAGE.map((line) => `  ${line}`),
  '',
  `  pod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'`,
  `  pod 'SallaPushExtension', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'`,
  'end',
  '# @generated end sallapush-nse',
  '',
].join('\n');

describe.each(['sdk-54', 'sdk-57'])('the Expo %s Podfile', (sdk) => {
  const podfile = fixture(`${sdk}/Podfile`);
  const withApp = podfile.replace(
    '  use_expo_modules!\n',
    `  use_expo_modules!\n${PODS}\n`
  );

  it('gets the app pods right after use_expo_modules!', () => {
    expect(addPods(podfile, false)).toBe(withApp);
  });

  it("gets the extension's target at the end, with the app's linkage", () => {
    expect(addPods(podfile, true)).toBe(`${withApp}${NSE_PODS}`);
  });

  it("repeats the template's own linkage lines", () => {
    for (const line of LINKAGE) {
      expect(podfile).toContain(`  ${line}\n`);
    }
  });

  it('is unchanged by a second run', () => {
    const result = addPods(podfile, true);

    expect(addPods(result, true)).toBe(result);
  });
});

describe('addPods', () => {
  it('pins the pods to the SallaPush iOS version of the podspec', () => {
    const podspec = fs.readFileSync(
      path.join(__dirname, '..', '..', 'SallaPushReactNative.podspec'),
      'utf8'
    );

    expect(podspec).toContain(
      `s.dependency "SallaPush", "${SALLAPUSH_IOS_VERSION}"`
    );
  });

  it('updates the pods of an earlier run in place', () => {
    const current = addPods(fixture('sdk-57/Podfile'), true);
    const earlier = current.replaceAll(
      `:tag => '${SALLAPUSH_IOS_VERSION}'`,
      ":tag => '0.9.0'"
    );

    expect(addPods(earlier, true)).toBe(current);
  });

  it('throws with the pod lines when the Podfile has no use_expo_modules!', () => {
    expect(() =>
      addPods("target 'HelloWorld' do\n  use_native_modules!\nend\n", true)
    ).toThrow(
      `@salla.sa/mobile-push-react-native: ios/Podfile has no use_expo_modules! line. Add these lines to the app target by hand:\n\npod 'SallaPushCore', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'\npod 'SallaPush', :git => 'https://github.com/SallaApp/mobile-push-ios-sdk.git', :tag => '${SALLAPUSH_IOS_VERSION}'`
    );
  });
});

describe('withSallaPushPodfile', () => {
  const root = tempProject({
    'package.json': '{ "dependencies": { "expo": "57.0.28" } }',
    'ios/Podfile': fixture('sdk-57/Podfile'),
  });

  afterAll(() => {
    fs.rmSync(root, { recursive: true, force: true });
  });

  it('edits ios/Podfile in the project through a dangerous mod', async () => {
    const config = withSallaPushPodfile(appConfig(), {});

    await runMod(config, 'ios', 'dangerous', undefined, root);
    await runMod(config, 'ios', 'dangerous', undefined, root);

    expect(fs.readFileSync(path.join(root, 'ios', 'Podfile'), 'utf8')).toBe(
      addPods(fixture('sdk-57/Podfile'), true)
    );
  });

  it('adds no extension target with notificationServiceExtension: false', async () => {
    const other = tempProject({
      'package.json': '{}',
      'ios/Podfile': fixture('sdk-57/Podfile'),
    });
    const config = withSallaPushPodfile(appConfig(), {
      notificationServiceExtension: false,
    });

    await runMod(config, 'ios', 'dangerous', undefined, other);

    expect(fs.readFileSync(path.join(other, 'ios', 'Podfile'), 'utf8')).toBe(
      addPods(fixture('sdk-57/Podfile'), false)
    );
    fs.rmSync(other, { recursive: true, force: true });
  });
});
