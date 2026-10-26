import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  jest,
} from '@jest/globals';

import NativeRNSallaPush from '../NativeRNSallaPush';
import {
  SallaPush,
  SallaPushAPNsEnvironment,
  SallaPushLogLevel,
  type SallaPushConfig,
} from '../index';

jest.mock('../NativeRNSallaPush');

const native = jest.mocked(NativeRNSallaPush);
let warn: jest.SpiedFunction<typeof console.warn>;

beforeEach(() => {
  jest.clearAllMocks();
  warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
});

afterEach(() => {
  warn.mockRestore();
});

describe('SallaPush.initialize', () => {
  it('passes the app id and every option', () => {
    SallaPush.initialize('st_42_rn', {
      logLevel: SallaPushLogLevel.Debug,
      appVersion: '2.1.0',
      clearTagsOnLogout: false,
      requiresUserConsent: true,
      openLaunchUrls: true,
      autoClearBadge: false,
      autoUpdateBadge: false,
      ios: {
        appGroupIdentifier: 'group.sa.salla.example',
        apnsEnvironment: SallaPushAPNsEnvironment.Sandbox,
        registerForRemoteNotificationsOnInit: false,
      },
    });

    expect(native.initWithAppId).toHaveBeenCalledTimes(1);
    expect(native.initWithAppId).toHaveBeenCalledWith('st_42_rn', {
      logLevel: 'debug',
      appVersion: '2.1.0',
      clearTagsOnLogout: false,
      requiresUserConsent: true,
      openLaunchUrls: true,
      autoClearBadge: false,
      autoUpdateBadge: false,
      iosAppGroupIdentifier: 'group.sa.salla.example',
      iosApnsEnvironment: 'sandbox',
      iosRegisterForRemoteNotificationsOnInit: false,
    });
  });

  // Each boolean alone, at the value that isn't native's default, so options swapped with each other can't pass.
  it.each<[SallaPushConfig, Record<string, boolean>]>([
    [{ clearTagsOnLogout: false }, { clearTagsOnLogout: false }],
    [{ requiresUserConsent: true }, { requiresUserConsent: true }],
    [{ openLaunchUrls: true }, { openLaunchUrls: true }],
    [{ autoClearBadge: false }, { autoClearBadge: false }],
    [{ autoUpdateBadge: false }, { autoUpdateBadge: false }],
    [
      { ios: { registerForRemoteNotificationsOnInit: false } },
      { iosRegisterForRemoteNotificationsOnInit: false },
    ],
  ])('passes %j as %j, and no other option', (config, spec) => {
    SallaPush.initialize('st_42_rn', config);

    expect(native.initWithAppId.mock.calls).toEqual([['st_42_rn', spec]]);
  });

  it('passes no options without a config', () => {
    SallaPush.initialize('st_42_rn');

    expect(native.initWithAppId).toHaveBeenCalledWith('st_42_rn', {});
  });

  it('leaves out options that are undefined or null, so native keeps its defaults', () => {
    SallaPush.initialize('st_42_rn', {
      logLevel: undefined,
      appVersion: null,
      openLaunchUrls: true,
      ios: { apnsEnvironment: SallaPushAPNsEnvironment.Production },
    } as unknown as SallaPushConfig);

    expect(native.initWithAppId).toHaveBeenCalledWith('st_42_rn', {
      openLaunchUrls: true,
      iosApnsEnvironment: 'production',
    });
    expect(warn).not.toHaveBeenCalled();
  });

  it('passes the app id unchanged, for native to validate', () => {
    SallaPush.initialize(' st_42 rn ');

    expect(native.initWithAppId).toHaveBeenCalledWith(' st_42 rn ', {});
  });

  it('drops a call whose app id is not a string, with one warning', () => {
    SallaPush.initialize(42 as unknown as string);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.initialize ignored: appId must be a string.'
    );
  });

  it('drops a call whose config is not a plain object', () => {
    SallaPush.initialize('st_42_rn', ['debug'] as unknown as SallaPushConfig);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.initialize ignored: config must be a plain object.'
    );
  });

  it('drops a call with an unknown log level', () => {
    SallaPush.initialize('st_42_rn', {
      logLevel: 'Debug',
    } as unknown as SallaPushConfig);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      "[SallaPush] SallaPush.initialize ignored: config.logLevel must be one of 'off', 'error', 'warn', " +
        "'info', 'debug', 'verbose'."
    );
  });

  it('drops a call with a mistyped option', () => {
    SallaPush.initialize('st_42_rn', {
      requiresUserConsent: 'true',
    } as unknown as SallaPushConfig);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.initialize ignored: config.requiresUserConsent must be a boolean.'
    );
  });

  it.each(['autoClearBadge', 'autoUpdateBadge'])(
    'drops a call whose %s is not a boolean',
    (option) => {
      SallaPush.initialize('st_42_rn', {
        [option]: 'false',
      } as unknown as SallaPushConfig);

      expect(native.initWithAppId).not.toHaveBeenCalled();
      expect(warn).toHaveBeenCalledWith(
        `[SallaPush] SallaPush.initialize ignored: config.${option} must be a boolean.`
      );
    }
  );

  it('drops a call whose iOS options are not an object', () => {
    SallaPush.initialize('st_42_rn', {
      ios: 'sandbox',
    } as unknown as SallaPushConfig);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.initialize ignored: config.ios must be a plain object.'
    );
  });

  it('drops a call with an unknown APNs environment', () => {
    SallaPush.initialize('st_42_rn', {
      ios: { apnsEnvironment: 'development' },
    } as unknown as SallaPushConfig);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      "[SallaPush] SallaPush.initialize ignored: config.ios.apnsEnvironment must be one of 'automatic', " +
        "'sandbox', 'production'."
    );
  });

  it('warns once per method and parameter, and drops every such call', () => {
    const config = {
      ios: { registerForRemoteNotificationsOnInit: 1 },
    } as unknown as SallaPushConfig;

    SallaPush.initialize('st_42_rn', config);
    SallaPush.initialize('st_42_rn', config);

    expect(native.initWithAppId).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.initialize ignored: config.ios.registerForRemoteNotificationsOnInit must be a boolean.'
    );
  });
});

describe('SallaPush getters', () => {
  it('resolve the values native reads at call time', async () => {
    native.isInitialized.mockResolvedValueOnce(true);
    native.getAppId.mockResolvedValueOnce('st_42_rn');
    native.getSdkVersion.mockResolvedValueOnce('1.1.0');

    await expect(SallaPush.isInitialized()).resolves.toBe(true);
    await expect(SallaPush.getAppId()).resolves.toBe('st_42_rn');
    await expect(SallaPush.getSdkVersion()).resolves.toBe('1.1.0');
  });

  it('resolve native null before initialization', async () => {
    await expect(SallaPush.isInitialized()).resolves.toBe(false);
    await expect(SallaPush.getAppId()).resolves.toBeNull();
  });
});

describe('SallaPush consent', () => {
  it.each([true, false])('passes setConsentRequired(%s)', (required) => {
    SallaPush.setConsentRequired(required);

    expect(native.setConsentRequired).toHaveBeenCalledWith(required);
  });

  it.each([true, false])('passes setConsentGiven(%s)', (given) => {
    SallaPush.setConsentGiven(given);

    expect(native.setConsentGiven).toHaveBeenCalledWith(given);
  });

  it('drops consent calls that are not booleans', () => {
    SallaPush.setConsentRequired('true' as unknown as boolean);
    SallaPush.setConsentGiven(1 as unknown as boolean);

    expect(native.setConsentRequired).not.toHaveBeenCalled();
    expect(native.setConsentGiven).not.toHaveBeenCalled();
    expect(warn.mock.calls).toEqual([
      [
        '[SallaPush] SallaPush.setConsentRequired ignored: required must be a boolean.',
      ],
      [
        '[SallaPush] SallaPush.setConsentGiven ignored: given must be a boolean.',
      ],
    ]);
  });
});

describe('SallaPush identity', () => {
  it('passes both login arguments untrimmed, for native to normalise', () => {
    SallaPush.login(' customer-7 ', ' token ');

    expect(native.login).toHaveBeenCalledWith(' customer-7 ', ' token ');
  });

  it('drops a login with a numeric external id', () => {
    SallaPush.login(7 as unknown as string, 'token');

    expect(native.login).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.login ignored: externalId must be a string.'
    );
  });

  it('drops a login without an identity token', () => {
    (SallaPush.login as (externalId: string) => void)('customer-7');

    expect(native.login).not.toHaveBeenCalled();
    expect(warn).toHaveBeenCalledWith(
      '[SallaPush] SallaPush.login ignored: identityToken must be a string.'
    );
  });

  it('passes logout', () => {
    SallaPush.logout();

    expect(native.logout).toHaveBeenCalledTimes(1);
  });
});
