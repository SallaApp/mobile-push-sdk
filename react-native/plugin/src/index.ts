import { createRunOncePlugin, type ConfigPlugin } from 'expo/config-plugins';

import { withSallaPushFcmForwarding } from './android/fcmForwarding';
import {
  withSallaPushAndroidManifest,
  withSallaPushStrings,
} from './android/manifest';
import { withSallaPushSmallIcon } from './android/smallIcon';
import { PLUGIN_NAME } from './constants';
import { withSallaPushAppDelegate } from './ios/appDelegate';
import { withSallaPushEasExtension } from './ios/easExtensions';
import { withSallaPushEntitlements } from './ios/entitlements';
import { withSallaPushInfoPlist } from './ios/infoPlist';
import { withSallaPushNotificationServiceExtension } from './ios/nse';
import { withSallaPushPodfile } from './ios/podfile';
import type { SallaPushPluginProps } from './types';
import { validateProps } from './validate';

const withSallaPush: ConfigPlugin<SallaPushPluginProps | void> = (
  config,
  props
) => {
  const { ios, android } = validateProps(config, props);
  let result = withSallaPushInfoPlist(config, ios);
  result = withSallaPushEntitlements(result, ios);
  result = withSallaPushAppDelegate(result);
  result = withSallaPushPodfile(result, ios);
  if (ios.notificationServiceExtension !== false) {
    result = withSallaPushNotificationServiceExtension(result, ios);
    result = withSallaPushEasExtension(result, ios);
  }
  result = withSallaPushAndroidManifest(result, android);
  result = withSallaPushStrings(result, android);
  result = withSallaPushSmallIcon(result, android);
  return withSallaPushFcmForwarding(result, android);
};

export default createRunOncePlugin(withSallaPush, PLUGIN_NAME);
