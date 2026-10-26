import type { ExpoConfig } from 'expo/config';
import fs from 'fs';
import path from 'path';

import { PLUGIN_NAME } from './constants';
import type { SallaPushPluginProps } from './types';

export type IOSProps = NonNullable<SallaPushPluginProps['ios']>;
export type AndroidProps = NonNullable<SallaPushPluginProps['android']>;

/** The iOS options of the missing-app-id warning that SallaPush.initialize takes under `ios`, not at its top level. */
const INITIALIZE_IOS = new Set([
  'apnsEnvironment',
  'registerForRemoteNotificationsOnInit',
]);

/**
 * The ending of the missing-app-id warning: the options given that this package's start-up code reads only with the
 * app id, which JavaScript's initialize must pass instead.
 */
export function withoutAppId(
  platform: 'ios' | 'android',
  props: Readonly<Record<string, unknown>>,
  options: readonly string[]
): string {
  const given = options.filter((option) => props[option] !== undefined);
  const ignored = given.map((option) => `${platform}.${option}`);
  const initialize = given.map((option) =>
    platform === 'ios' && INITIALIZE_IOS.has(option) ? `ios.${option}` : option
  );
  return given.length === 0
    ? ''
    : ` Without it, SallaPush doesn't read ${ignored.join(', ')}; pass them to SallaPush.initialize instead, as ${initialize.join(', ')}.`;
}

/** What an option takes: a string, a boolean, or one of the listed strings. */
type Kind = 'string' | 'boolean' | readonly string[];

const IOS_KINDS: Record<keyof IOSProps, Kind> = {
  appId: 'string',
  mode: ['development', 'production'],
  appGroup: 'string',
  openLaunchUrls: 'boolean',
  requiresUserConsent: 'boolean',
  clearTagsOnLogout: 'boolean',
  autoClearBadge: 'boolean',
  autoUpdateBadge: 'boolean',
  registerForRemoteNotificationsOnInit: 'boolean',
  apnsEnvironment: ['automatic', 'sandbox', 'production'],
  appVersion: 'string',
  logLevel: ['off', 'error', 'warn', 'info', 'debug', 'verbose'],
  notificationServiceExtension: 'boolean',
  developmentTeam: 'string',
};

const ANDROID_KINDS: Record<keyof AndroidProps, Kind> = {
  appId: 'string',
  smallIcon: 'string',
  defaultChannelId: 'string',
  defaultChannelName: 'string',
  openLaunchUrls: 'boolean',
  requiresUserConsent: 'boolean',
  clearTagsOnLogout: 'boolean',
  autoClearBadge: 'boolean',
  autoUpdateBadge: 'boolean',
  appVersion: 'string',
  logLevel: ['off', 'error', 'warn', 'info', 'debug', 'verbose'],
  displayCompatPayloads: 'boolean',
  fcmForwarding: [
    'auto',
    'none',
    'expo-notifications',
    '@react-native-firebase/messaging',
  ],
};

// Native's rule: an invalid first app id disables SallaPush until the next launch.
const APP_ID = /^[A-Za-z0-9_-]{1,64}$/;

// A drawable the app has, with a name AAPT accepts, or a PNG file to copy.
function isSmallIcon(value: string): boolean {
  return value.startsWith('@')
    ? /^@drawable\/[a-z][a-z0-9_]*$/.test(value)
    : /\.png$/i.test(value);
}

function fail(message: string): Error {
  return new Error(`${PLUGIN_NAME}: ${message}`);
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function expectation(kind: Kind): string {
  if (kind === 'string') {
    return 'a string';
  }
  if (kind === 'boolean') {
    return 'true or false';
  }
  return `one of ${kind.map((value) => JSON.stringify(value)).join(', ')}`;
}

function matches(value: unknown, kind: Kind): boolean {
  return typeof kind === 'string'
    ? typeof value === kind
    : kind.includes(value as string);
}

/** The options under `name` with their types checked; null and undefined values are left out. */
function checked<T>(
  value: unknown,
  name: string,
  kinds: Record<string, Kind>
): T {
  if (value === undefined || value === null) {
    return {} as T;
  }
  if (!isObject(value)) {
    throw fail(`${name} must be an object.`);
  }
  const result: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) {
    const kind = kinds[key];
    if (kind === undefined) {
      throw fail(
        `unknown option ${name}.${key}. The ${name} options are ${Object.keys(kinds).join(', ')}.`
      );
    }
    if (entry === undefined || entry === null) {
      continue;
    }
    if (!matches(entry, kind)) {
      throw fail(`${name}.${key} must be ${expectation(kind)}.`);
    }
    result[key] = entry;
  }
  return result as T;
}

function requireNewArchitecture(config: ExpoConfig): void {
  const owners: Record<string, unknown> = {
    'newArchEnabled': config,
    'ios.newArchEnabled': config.ios,
    'android.newArchEnabled': config.android,
  };
  for (const [name, owner] of Object.entries(owners)) {
    if (isObject(owner) && owner.newArchEnabled === false) {
      throw fail(
        `the SallaPush module needs React Native's New Architecture, and the app config sets ${name}: false. Remove that setting.`
      );
    }
  }
}

function checkAppId(appId: string | undefined, name: string): void {
  if (appId !== undefined && !APP_ID.test(appId)) {
    throw fail(
      `${name} ${JSON.stringify(appId)} is not a SallaPush app id, which has 1 to 64 letters, digits, "_" or "-". Use the app id the Salla team gave you.`
    );
  }
}

/** Checks the plugin options and the app config, and returns the options without null or undefined values. */
export function validateProps(
  config: ExpoConfig,
  props: unknown
): { ios: IOSProps; android: AndroidProps } {
  requireNewArchitecture(config);
  if (props !== undefined && props !== null && !isObject(props)) {
    throw fail(
      'the plugin options must be an object, such as { "ios": { "appId": "…" } }.'
    );
  }
  for (const key of Object.keys(props ?? {})) {
    if (key !== 'ios' && key !== 'android') {
      throw fail(`unknown option ${key}. The options are ios, android.`);
    }
  }
  const ios = checked<IOSProps>(
    isObject(props) ? props.ios : undefined,
    'ios',
    IOS_KINDS
  );
  const android = checked<AndroidProps>(
    isObject(props) ? props.android : undefined,
    'android',
    ANDROID_KINDS
  );
  checkAppId(ios.appId, 'ios.appId');
  checkAppId(android.appId, 'android.appId');
  if (android.smallIcon !== undefined && !isSmallIcon(android.smallIcon)) {
    throw fail(
      `android.smallIcon ${JSON.stringify(android.smallIcon)} must be a .png file, such as "./assets/notification-icon.png", or a drawable, such as "@drawable/ic_notification".`
    );
  }
  if (
    ios.notificationServiceExtension !== false &&
    pluginOptions(config, 'onesignal-expo-plugin') !== undefined
  ) {
    throw fail(
      'onesignal-expo-plugin adds its own Notification Service Extension, and an app has only one. Set ios.notificationServiceExtension to false, and call SallaPush first in that extension (see the README).'
    );
  }
  return { ios, android };
}

/** The options the app config gives the config plugin `name`; undefined when the app doesn't use it. */
export function pluginOptions(config: ExpoConfig, name: string): unknown {
  for (const entry of config.plugins ?? []) {
    const [plugin, options] = Array.isArray(entry) ? entry : [entry];
    if (plugin === name) {
      return options ?? {};
    }
  }
  return undefined;
}

/** The packages the app's package.json lists in dependencies and devDependencies. */
export function projectDependencies(projectRoot: string): ReadonlySet<string> {
  const manifest: unknown = JSON.parse(
    fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf8')
  );
  const names = ['dependencies', 'devDependencies'].flatMap((field) => {
    const list = isObject(manifest) ? manifest[field] : undefined;
    return isObject(list) ? Object.keys(list) : [];
  });
  return new Set(names);
}
