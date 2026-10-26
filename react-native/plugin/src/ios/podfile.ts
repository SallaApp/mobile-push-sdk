import {
  WarningAggregator,
  withDangerousMod,
  type ConfigPlugin,
} from 'expo/config-plugins';
import fs from 'fs';
import path from 'path';

import {
  NSE_TARGET,
  PLUGIN_NAME,
  SALLAPUSH_IOS_REPOSITORY,
  SALLAPUSH_IOS_VERSION,
} from '../constants';
import { indentOf, mergeBlock } from '../mergeBlock';
import {
  isObject,
  pluginOptions,
  projectDependencies,
  type IOSProps,
} from '../validate';

function pod(name: string): string {
  return `pod '${name}', :git => '${SALLAPUSH_IOS_REPOSITORY}', :tag => '${SALLAPUSH_IOS_VERSION}'`;
}

const APP_PODS = [pod('SallaPushCore'), pod('SallaPush')];

// Expo sets the linkage inside the app target only, so the extension's target repeats the template's two lines.
const NSE_PODS = [
  `target '${NSE_TARGET}' do`,
  "  use_frameworks! :linkage => podfile_properties['ios.useFrameworks'].to_sym if podfile_properties['ios.useFrameworks']",
  "  use_frameworks! :linkage => ENV['USE_FRAMEWORKS'].to_sym if ENV['USE_FRAMEWORKS']",
  '',
  `  ${pod('SallaPushCore')}`,
  `  ${pod('SallaPushExtension')}`,
  'end',
];

/**
 * Adds the SallaPush pods to the app target, after use_expo_modules!, and with `nse` a top-level target for the
 * Notification Service Extension at the end.
 */
export function addPods(podfile: string, nse: boolean): string {
  const updated = mergeBlock(
    podfile,
    { tag: 'pods', comment: '#', lines: APP_PODS },
    (lines) => {
      const index = lines.findIndex((line) =>
        /^\s*use_expo_modules!/.test(line)
      );
      return index === -1
        ? undefined
        : { index: index + 1, indent: indentOf(lines[index] ?? '') };
    }
  );
  if (updated === undefined) {
    throw new Error(
      `${PLUGIN_NAME}: ios/Podfile has no use_expo_modules! line. Add these lines to the app target by hand:\n\n${APP_PODS.join('\n')}`
    );
  }
  return nse
    ? mergeBlock(
        updated,
        { tag: 'nse', comment: '#', lines: NSE_PODS },
        (lines) => ({
          index: lines.at(-1) === '' ? lines.length - 1 : lines.length,
          indent: '',
        })
      )
    : updated;
}

/** React Native Firebase needs dynamic frameworks, which apps set with expo-build-properties. */
function usesDynamicFrameworks(options: unknown): boolean {
  const ios = isObject(options) ? options.ios : undefined;
  return isObject(ios) && ios.useFrameworks === 'dynamic';
}

export const withSallaPushPodfile: ConfigPlugin<IOSProps> = (config, ios) =>
  withDangerousMod(config, [
    'ios',
    async (mod) => {
      if (
        projectDependencies(mod.modRequest.projectRoot).has(
          '@react-native-firebase/messaging'
        ) &&
        !usesDynamicFrameworks(pluginOptions(mod, 'expo-build-properties'))
      ) {
        WarningAggregator.addWarningIOS(
          PLUGIN_NAME,
          '@react-native-firebase/messaging needs dynamic frameworks: add the expo-build-properties plugin with { "ios": { "useFrameworks": "dynamic" } }.'
        );
      }
      const file = path.join(mod.modRequest.platformProjectRoot, 'Podfile');
      const podfile = await fs.promises.readFile(file, 'utf8');
      const updated = addPods(
        podfile,
        ios.notificationServiceExtension !== false
      );
      if (updated !== podfile) {
        await fs.promises.writeFile(file, updated);
      }
      return mod;
    },
  ]);
