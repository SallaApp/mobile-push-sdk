import {
  WarningAggregator,
  withInfoPlist,
  type ConfigPlugin,
  type InfoPlist,
} from 'expo/config-plugins';

import { PLUGIN_NAME } from '../constants';
import { withoutAppId, type IOSProps } from '../validate';

/** The Info.plist key of each option. */
const KEYS = {
  appId: 'SallaPushAppId',
  openLaunchUrls: 'SallaPushOpenLaunchURLs',
  requiresUserConsent: 'SallaPushRequiresUserConsent',
  clearTagsOnLogout: 'SallaPushClearTagsOnLogout',
  appVersion: 'SallaPushAppVersion',
  autoClearBadge: 'SallaPushAutoClearBadge',
  autoUpdateBadge: 'SallaPushAutoUpdateBadge',
  registerForRemoteNotificationsOnInit:
    'SallaPushRegisterForRemoteNotificationsOnInit',
  apnsEnvironment: 'SallaPushAPNsEnvironment',
  logLevel: 'SallaPushLogLevel',
  appGroup: 'SallaPushAppGroup',
} as const satisfies Partial<Record<keyof IOSProps, string>>;

/** The options whose keys this package reads only when SallaPushAppId starts SallaPush; native reads the others. */
const WITH_APP_ID = [
  'requiresUserConsent',
  'openLaunchUrls',
  'clearTagsOnLogout',
  'appVersion',
  'autoClearBadge',
  'autoUpdateBadge',
  'registerForRemoteNotificationsOnInit',
  'apnsEnvironment',
] as const satisfies readonly (keyof IOSProps)[];

/** Adds the remote-notification background mode and the key of every option given. */
export function setInfoPlist(infoPlist: InfoPlist, ios: IOSProps): InfoPlist {
  const modes = Array.isArray(infoPlist.UIBackgroundModes)
    ? infoPlist.UIBackgroundModes
    : [];
  infoPlist.UIBackgroundModes = [...new Set([...modes, 'remote-notification'])];
  for (const [option, key] of Object.entries(KEYS)) {
    const value = ios[option as keyof typeof KEYS];
    if (value !== undefined) {
      infoPlist[key] = value;
    }
  }
  return infoPlist;
}

export const withSallaPushInfoPlist: ConfigPlugin<IOSProps> = (config, ios) =>
  withInfoPlist(config, (mod) => {
    if (ios.appId === undefined) {
      WarningAggregator.addWarningIOS(
        PLUGIN_NAME,
        'ios.appId is not set, so on iOS SallaPush starts only when JavaScript calls SallaPush.initialize.' +
          withoutAppId('ios', ios, WITH_APP_ID)
      );
    }
    mod.modResults = setInfoPlist(mod.modResults, ios);
    return mod;
  });
