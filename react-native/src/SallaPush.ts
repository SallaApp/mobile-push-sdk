import NativeRNSallaPush, { type ConfigSpec } from './NativeRNSallaPush';
import { Debug } from './Debug';
import { Migration } from './Migration';
import { Notifications } from './Notifications';
import { User } from './User';
import {
  apnsEnvironment,
  boolean,
  logLevel,
  optional,
  record,
  string,
  valid,
} from './internal/validate';
import type {
  SallaPushConfig,
  SallaPushDebugNamespace,
  SallaPushMigrationNamespace,
  SallaPushNotificationsNamespace,
  SallaPushUserNamespace,
} from './types';

/** SallaPush for React Native. Every call is safe at any time, before or after initialization. */
export const SallaPush: {
  /**
   * Starts SallaPush when the app id is known only at run time. Apps that set the static app id (SallaPushAppId /
   * com.salla.push.APP_ID) never need it: SallaPush has already started natively, and a call with the same app id
   * changes nothing, its config included.
   */
  initialize(appId: string, config?: SallaPushConfig): void;
  /** Whether SallaPush is running, started from the static app id or by initialize. */
  isInitialized(): Promise<boolean>;
  /** The app id SallaPush runs with; null before it starts. */
  getAppId(): Promise<string | null>;
  /** The native SallaPush SDK version on this platform, for example "1.1.0". */
  getSdkVersion(): Promise<string>;
  /**
   * Requires consent before any data processing. With the static app id, require consent with the static key
   * (SallaPushRequiresUserConsent / com.salla.push.REQUIRES_USER_CONSENT) instead: SallaPush starts before JavaScript.
   */
  setConsentRequired(required: boolean): void;
  /**
   * The user's answer, saved for the app. While consent is required, false withdraws consent that was given: SallaPush
   * opts the device out, deletes its tags and unlinks the customer, then stays idle.
   */
  setConsentGiven(given: boolean): void;
  /**
   * Links this device to the customer `externalId` once Salla has checked `identityToken`. `externalId` is the
   * customer's id as Salla knows it, such as "42": the id of the token's customer. `identityToken` is the customer's
   * Salla token, the one your app received when the customer signed in, without a `Bearer ` prefix. The device is
   * linked only when the token belongs to that customer. SallaPush keeps the token in memory only, so call login again
   * whenever your app refreshes it, and at every launch. A refusal arrives as a 'loginFailure' event of
   * SallaPush.User, such as tokenRejected; there is no success event.
   */
  login(externalId: string, identityToken: string): void;
  /**
   * Unlinks the device from the customer; it stays registered as a guest. It needs no token and works offline. Call it
   * after sign-out, before another customer's login, and at each launch while nobody is signed in: on iOS, a reinstall
   * keeps the earlier install's customer linked until then. It sends nothing when the device isn't linked.
   */
  logout(): void;
  /** The customer, the device's tags and language, and the push subscription. */
  readonly User: SallaPushUserNamespace;
  /** The permission, taps, foreground notifications, and helpers for other SDKs' notifications. */
  readonly Notifications: SallaPushNotificationsNamespace;
  /** The console log level and the log handler. */
  readonly Debug: SallaPushDebugNamespace;
  /** Settings for compat-format notifications. */
  readonly Migration: SallaPushMigrationNamespace;
} = {
  initialize(appId, config) {
    if (
      !valid('SallaPush.initialize', {
        appId: [appId, string],
        config: [config, optional(record)],
      })
    ) {
      return;
    }
    const spec = configSpec(config ?? {});
    if (spec) {
      NativeRNSallaPush.initWithAppId(appId, spec);
    }
  },
  isInitialized: () => NativeRNSallaPush.isInitialized(),
  getAppId: () => NativeRNSallaPush.getAppId(),
  getSdkVersion: () => NativeRNSallaPush.getSdkVersion(),
  setConsentRequired(required) {
    if (
      valid('SallaPush.setConsentRequired', { required: [required, boolean] })
    ) {
      NativeRNSallaPush.setConsentRequired(required);
    }
  },
  setConsentGiven(given) {
    if (valid('SallaPush.setConsentGiven', { given: [given, boolean] })) {
      NativeRNSallaPush.setConsentGiven(given);
    }
  },
  login(externalId, identityToken) {
    if (
      valid('SallaPush.login', {
        externalId: [externalId, string],
        identityToken: [identityToken, string],
      })
    ) {
      NativeRNSallaPush.login(externalId, identityToken);
    }
  },
  logout: () => NativeRNSallaPush.logout(),
  User,
  Notifications,
  Debug,
  Migration,
};

/** The config as the TurboModule takes it, with only the options that are set; null when an option is mistyped. */
function configSpec(config: SallaPushConfig): ConfigSpec | null {
  if (
    !valid('SallaPush.initialize', {
      'config.logLevel': [config.logLevel, optional(logLevel)],
      'config.appVersion': [config.appVersion, optional(string)],
      'config.clearTagsOnLogout': [config.clearTagsOnLogout, optional(boolean)],
      'config.requiresUserConsent': [
        config.requiresUserConsent,
        optional(boolean),
      ],
      'config.openLaunchUrls': [config.openLaunchUrls, optional(boolean)],
      'config.autoClearBadge': [config.autoClearBadge, optional(boolean)],
      'config.autoUpdateBadge': [config.autoUpdateBadge, optional(boolean)],
      'config.ios': [config.ios, optional(record)],
    })
  ) {
    return null;
  }
  const ios = config.ios ?? {};
  if (
    !valid('SallaPush.initialize', {
      'config.ios.appGroupIdentifier': [
        ios.appGroupIdentifier,
        optional(string),
      ],
      'config.ios.apnsEnvironment': [
        ios.apnsEnvironment,
        optional(apnsEnvironment),
      ],
      'config.ios.registerForRemoteNotificationsOnInit': [
        ios.registerForRemoteNotificationsOnInit,
        optional(boolean),
      ],
    })
  ) {
    return null;
  }
  return setFields({
    logLevel: config.logLevel,
    appVersion: config.appVersion,
    clearTagsOnLogout: config.clearTagsOnLogout,
    requiresUserConsent: config.requiresUserConsent,
    openLaunchUrls: config.openLaunchUrls,
    autoClearBadge: config.autoClearBadge,
    autoUpdateBadge: config.autoUpdateBadge,
    iosAppGroupIdentifier: ios.appGroupIdentifier,
    iosApnsEnvironment: ios.apnsEnvironment,
    iosRegisterForRemoteNotificationsOnInit:
      ios.registerForRemoteNotificationsOnInit,
  });
}

/** The fields that are set, so the bridges read every other option as native's default. */
function setFields(spec: ConfigSpec): ConfigSpec {
  return Object.fromEntries(
    Object.entries(spec).filter(
      ([, value]) => value !== undefined && value !== null
    )
  ) as ConfigSpec;
}
