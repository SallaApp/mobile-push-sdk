import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';
import { WarningAggregator, type InfoPlist } from 'expo/config-plugins';

import { setInfoPlist, withSallaPushInfoPlist } from '../src/ios/infoPlist';
import { appConfig, runMod } from './mods';

let warn: jest.SpiedFunction<typeof WarningAggregator.addWarningIOS>;

beforeEach(() => {
  warn = jest
    .spyOn(WarningAggregator, 'addWarningIOS')
    .mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
});

describe('setInfoPlist', () => {
  it('writes the key of every option', () => {
    const infoPlist = setInfoPlist(
      {},
      {
        appId: 'st_42_ios',
        mode: 'production',
        appGroup: 'group.sa.salla.example',
        openLaunchUrls: true,
        requiresUserConsent: true,
        clearTagsOnLogout: false,
        autoClearBadge: false,
        autoUpdateBadge: true,
        registerForRemoteNotificationsOnInit: false,
        apnsEnvironment: 'sandbox',
        appVersion: '2.1.0',
        logLevel: 'debug',
      }
    );

    expect(infoPlist).toEqual({
      UIBackgroundModes: ['remote-notification'],
      SallaPushAppId: 'st_42_ios',
      SallaPushAppGroup: 'group.sa.salla.example',
      SallaPushOpenLaunchURLs: true,
      SallaPushRequiresUserConsent: true,
      SallaPushClearTagsOnLogout: false,
      SallaPushAutoClearBadge: false,
      SallaPushAutoUpdateBadge: true,
      SallaPushRegisterForRemoteNotificationsOnInit: false,
      SallaPushAPNsEnvironment: 'sandbox',
      SallaPushAppVersion: '2.1.0',
      SallaPushLogLevel: 'debug',
    });
  });

  it('writes no SallaPush key for absent options and keeps the existing ones', () => {
    const infoPlist = setInfoPlist(
      { CFBundleName: 'Hello', SallaPushLogLevel: 'info' },
      {}
    );

    expect(infoPlist).toEqual({
      CFBundleName: 'Hello',
      SallaPushLogLevel: 'info',
      UIBackgroundModes: ['remote-notification'],
    });
  });

  it('adds remote-notification to the background modes once', () => {
    const once = setInfoPlist(
      { UIBackgroundModes: ['audio', 'remote-notification', 'audio'] },
      {}
    );
    const twice = setInfoPlist(once, {});

    expect(twice.UIBackgroundModes).toEqual(['audio', 'remote-notification']);
  });

  it('keeps the other background modes', () => {
    expect(
      setInfoPlist({ UIBackgroundModes: ['fetch'] }, {}).UIBackgroundModes
    ).toEqual(['fetch', 'remote-notification']);
  });
});

describe('withSallaPushInfoPlist', () => {
  it('edits the Info.plist through the infoPlist mod', async () => {
    const config = withSallaPushInfoPlist(appConfig(), { appId: 'st_42_ios' });

    const { modResults } = await runMod<InfoPlist>(
      config,
      'ios',
      'infoPlist',
      {}
    );

    expect(modResults).toEqual({
      UIBackgroundModes: ['remote-notification'],
      SallaPushAppId: 'st_42_ios',
    });
    expect(warn).not.toHaveBeenCalled();
  });

  it('warns that SallaPush starts from JavaScript without ios.appId', async () => {
    const config = withSallaPushInfoPlist(appConfig(), {});

    await runMod<InfoPlist>(config, 'ios', 'infoPlist', {});

    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '@salla.sa/mobile-push-react-native',
      'ios.appId is not set, so on iOS SallaPush starts only when JavaScript calls SallaPush.initialize.'
    );
  });

  it('names the options that SallaPush reads only with ios.appId', async () => {
    const config = withSallaPushInfoPlist(appConfig(), {
      requiresUserConsent: true,
      appVersion: '2.1.0',
      autoClearBadge: false,
      autoUpdateBadge: false,
      apnsEnvironment: 'sandbox',
      logLevel: 'info',
      appGroup: 'group.sa.salla.example',
    });

    await runMod<InfoPlist>(config, 'ios', 'infoPlist', {});

    expect(warn).toHaveBeenCalledWith(
      '@salla.sa/mobile-push-react-native',
      "ios.appId is not set, so on iOS SallaPush starts only when JavaScript calls SallaPush.initialize. Without it, SallaPush doesn't read ios.requiresUserConsent, ios.appVersion, ios.autoClearBadge, ios.autoUpdateBadge, ios.apnsEnvironment; pass them to SallaPush.initialize instead, as requiresUserConsent, appVersion, autoClearBadge, autoUpdateBadge, ios.apnsEnvironment."
    );
  });
});
