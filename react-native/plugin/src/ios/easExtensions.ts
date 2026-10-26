import type { ConfigPlugin } from 'expo/config-plugins';

import { NSE_TARGET } from '../constants';
import { isObject, type IOSProps } from '../validate';

function child(value: unknown, key: string): Record<string, unknown> {
  const found = isObject(value) ? value[key] : undefined;
  return isObject(found) ? found : {};
}

/**
 * Lists the extension in extra.eas.build.experimental.ios.appExtensions, where EAS Build finds the targets to sign,
 * once, and keeps the other entries.
 */
export const withSallaPushEasExtension: ConfigPlugin<IOSProps> = (
  config,
  ios
) => {
  const bundleIdentifier = config.ios?.bundleIdentifier;
  if (bundleIdentifier === undefined) {
    return config;
  }
  const extension = {
    targetName: NSE_TARGET,
    bundleIdentifier: `${bundleIdentifier}.${NSE_TARGET}`,
    entitlements:
      ios.appGroup === undefined
        ? {}
        : { 'com.apple.security.application-groups': [ios.appGroup] },
  };
  const eas = child(config.extra, 'eas');
  const build = child(eas, 'build');
  const experimental = child(build, 'experimental');
  const iosBuild = child(experimental, 'ios');
  const listed = Array.isArray(iosBuild.appExtensions)
    ? iosBuild.appExtensions
    : [];
  const appExtensions = [
    ...listed.filter(
      (entry) => !isObject(entry) || entry.targetName !== NSE_TARGET
    ),
    extension,
  ];
  return {
    ...config,
    extra: {
      ...config.extra,
      eas: {
        ...eas,
        build: {
          ...build,
          experimental: {
            ...experimental,
            ios: { ...iosBuild, appExtensions },
          },
        },
      },
    },
  };
};
