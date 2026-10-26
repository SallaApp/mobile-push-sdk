import type { ExpoConfig } from 'expo/config';
import {
  AndroidConfig,
  withDangerousMod,
  type ConfigPlugin,
} from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

import { PLUGIN_NAME } from '../constants';
import { readTemplate, render } from '../templates';
import { projectDependencies, type AndroidProps } from '../validate';

/** The FCM service of each library that takes FCM from SallaPush's own; the app's service extends it. */
const LIBRARIES = {
  'expo-notifications':
    'expo.modules.notifications.service.ExpoFirebaseMessagingService',
  '@react-native-firebase/messaging':
    'io.invertase.firebase.messaging.ReactNativeFirebaseMessagingService',
} as const;

export type ForwardingLibrary = keyof typeof LIBRARIES;

export const SERVICE = 'SallaPushMessagingService';
const TEMPLATE = `${SERVICE}.kt.tmpl`;

/** The library whose service the forwarding service extends; undefined when FCM can stay with SallaPush's own. */
export function forwardingLibrary(
  android: AndroidProps,
  dependencies: ReadonlySet<string>
): ForwardingLibrary | undefined {
  const setting = android.fcmForwarding ?? 'auto';
  if (setting !== 'auto') {
    return setting === 'none' ? undefined : setting;
  }
  const found = (Object.keys(LIBRARIES) as ForwardingLibrary[]).filter(
    (library) => dependencies.has(library)
  );
  if (found.length > 1) {
    throw new Error(
      `${PLUGIN_NAME}: the app has both ${found.join(' and ')}, and only one FCM service gets the messages. Set android.fcmForwarding to the library that receives FCM in this app.`
    );
  }
  return found[0];
}

/** The forwarding service's Kotlin source, in the app's package, with Kotlin keywords such as `in` quoted, as Expo does. */
export function serviceSource(
  packageName: string,
  library: ForwardingLibrary
): string {
  const baseClass = LIBRARIES[library];
  return render(readTemplate(TEMPLATE), {
    package: AndroidConfig.Package.kotlinSanitized(packageName),
    baseClass,
    baseName: baseClass.slice(baseClass.lastIndexOf('.') + 1),
  });
}

function appPackage(config: Pick<ExpoConfig, 'android'>): string {
  const packageName = AndroidConfig.Package.getPackage(config);
  if (packageName === null) {
    throw new Error(
      `${PLUGIN_NAME}: forwarding FCM to SallaPush needs android.package in the app config.`
    );
  }
  return packageName;
}

/** The forwarding service's class, in the app's package. */
export function serviceName(config: Pick<ExpoConfig, 'android'>): string {
  return `${appPackage(config)}.${SERVICE}`;
}

/** Whether a prebuild generated `file`: it starts with the template's first line. */
function isGenerated(file: string): boolean {
  return fs
    .readFileSync(file, 'utf8')
    .startsWith(readTemplate(TEMPLATE).split('\n')[0] ?? '');
}

/**
 * Writes android/app/src/main/java/<package>/SallaPushMessagingService.kt when another library owns FCM, and deletes the
 * one an earlier prebuild wrote once none does, since its base class may be gone. A file of the app's own there is
 * never overwritten or deleted: forwarding then throws.
 */
export const withSallaPushFcmForwarding: ConfigPlugin<AndroidProps> = (
  config,
  android
) =>
  withDangerousMod(config, [
    'android',
    async (mod) => {
      const library = forwardingLibrary(
        android,
        projectDependencies(mod.modRequest.projectRoot)
      );
      if (
        library === undefined &&
        AndroidConfig.Package.getPackage(mod) === null
      ) {
        return mod;
      }
      const packageName = appPackage(mod);
      const file = path.join(
        mod.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
        'java',
        ...packageName.split('.'),
        `${SERVICE}.kt`
      );
      if (library !== undefined) {
        if (fs.existsSync(file) && !isGenerated(file)) {
          throw new Error(
            `${PLUGIN_NAME}: ${path.relative(mod.modRequest.projectRoot, file)} is the app's own file, not the plugin's, so the plugin doesn't overwrite it. Set android.fcmForwarding to 'none' to keep it, or delete it to use the plugin's.`
          );
        }
        await fs.promises.mkdir(path.dirname(file), { recursive: true });
        await fs.promises.writeFile(file, serviceSource(packageName, library));
      } else if (fs.existsSync(file) && isGenerated(file)) {
        await fs.promises.rm(file);
      }
      return mod;
    },
  ]);
