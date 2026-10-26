import {
  withEntitlementsPlist,
  type ConfigPlugin,
  type InfoPlist,
} from 'expo/config-plugins';

import type { IOSProps } from '../validate';

const APP_GROUPS = 'com.apple.security.application-groups';

/** Sets aps-environment when the app has none, and adds the App Group once. */
export function setEntitlements(
  entitlements: InfoPlist,
  ios: IOSProps
): InfoPlist {
  const environment = entitlements['aps-environment'];
  if (typeof environment !== 'string' || environment === '') {
    entitlements['aps-environment'] = ios.mode ?? 'development';
  }
  if (ios.appGroup !== undefined) {
    const groups = entitlements[APP_GROUPS];
    const list = Array.isArray(groups) ? groups : [];
    if (!list.includes(ios.appGroup)) {
      entitlements[APP_GROUPS] = [...list, ios.appGroup];
    }
  }
  return entitlements;
}

export const withSallaPushEntitlements: ConfigPlugin<IOSProps> = (
  config,
  ios
) =>
  withEntitlementsPlist(config, (mod) => {
    mod.modResults = setEntitlements(mod.modResults, ios);
    return mod;
  });
