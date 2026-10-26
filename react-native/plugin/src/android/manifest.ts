import {
  AndroidConfig,
  WarningAggregator,
  XML,
  withAndroidManifest,
  withStringsXml,
  type ConfigPlugin,
} from 'expo/config-plugins';

import { PLUGIN_NAME } from '../constants';
import {
  projectDependencies,
  withoutAppId,
  type AndroidProps,
} from '../validate';
import { forwardingLibrary, SERVICE, serviceName } from './fcmForwarding';
import { iconResource } from './smallIcon';

type AndroidManifest = AndroidConfig.Manifest.AndroidManifest;
type Application = AndroidConfig.Manifest.ManifestApplication;
type ResourceXML = AndroidConfig.Resources.ResourceXML;
type Service = NonNullable<Application['service']>[number] & {
  'meta-data'?: AndroidConfig.Manifest.ManifestMetaData[];
};

/** The meta-data that marks the forwarding service as the plugin's; a service without it is the app's own. */
const GENERATED = 'sa.salla.sallapush.reactnative.GENERATED';

function isGenerated(service: Service): boolean {
  return (
    service['meta-data']?.some(
      ({ $ }) =>
        $['android:name'] === GENERATED && $['android:value'] === 'true'
    ) ?? false
  );
}

/** The meta-data name of each option. */
const KEYS = {
  appId: 'com.salla.push.APP_ID',
  openLaunchUrls: 'com.salla.push.OPEN_LAUNCH_URLS',
  requiresUserConsent: 'com.salla.push.REQUIRES_USER_CONSENT',
  clearTagsOnLogout: 'com.salla.push.CLEAR_TAGS_ON_LOGOUT',
  autoClearBadge: 'com.salla.push.AUTO_CLEAR_BADGE',
  autoUpdateBadge: 'com.salla.push.AUTO_UPDATE_BADGE',
  appVersion: 'com.salla.push.APP_VERSION',
  displayCompatPayloads: 'com.salla.push.DISPLAY_COMPAT_PAYLOADS',
  logLevel: 'com.salla.push.LOG_LEVEL',
  defaultChannelId: 'com.salla.push.default_channel_id',
  defaultChannelName: 'com.salla.push.default_channel_name',
} as const satisfies Partial<Record<keyof AndroidProps, string>>;

const ICON = 'com.salla.push.default_notification_icon';

/** The options whose meta-data this package reads only when com.salla.push.APP_ID starts SallaPush. */
const WITH_APP_ID = [
  'requiresUserConsent',
  'openLaunchUrls',
  'clearTagsOnLogout',
  'appVersion',
  'autoClearBadge',
  'autoUpdateBadge',
] as const satisfies readonly (keyof AndroidProps)[];

/**
 * The string resource of each string option. AAPT types a literal android:value, so "2.10" would arrive as the float
 * 2.1 and "007" as the integer 7, while a string resource's value arrives as its exact text.
 */
const STRINGS: Partial<Record<keyof typeof KEYS, string>> = {
  appId: 'sallapush_app_id',
  appVersion: 'sallapush_app_version',
  defaultChannelId: 'sallapush_default_channel_id',
  defaultChannelName: 'sallapush_default_channel_name',
};

/** Adds the meta-data element `name`, replacing one with the same name. */
function setMetaData(
  application: Application,
  name: string,
  value: string,
  type: 'value' | 'resource'
): void {
  AndroidConfig.Manifest.removeMetaDataItemFromMainApplication(
    application,
    name
  );
  AndroidConfig.Manifest.addMetaDataItemToMainApplication(
    application,
    name,
    value,
    type
  );
}

/**
 * Writes the meta-data of every option given, a string option's as its string resource, the small icon's only with
 * smallIcon, and the forwarding service at priority 1 when `service` names one; an earlier prebuild's service, marked
 * as the plugin's, is replaced or removed, and so is its meta-data of a string option no longer given, whose resource
 * setStrings removes. The app's own services stay, and one of the class `service` names throws.
 */
export function setManifest(
  manifest: AndroidManifest,
  android: AndroidProps,
  service: string | undefined
): AndroidManifest {
  const application =
    AndroidConfig.Manifest.getMainApplicationOrThrow(manifest);
  for (const [option, name] of Object.entries(KEYS)) {
    const value = android[option as keyof typeof KEYS];
    const resource = STRINGS[option as keyof typeof KEYS];
    if (value !== undefined) {
      setMetaData(
        application,
        name,
        resource === undefined ? String(value) : `@string/${resource}`,
        'value'
      );
    } else if (
      resource !== undefined &&
      application['meta-data']?.some(
        ({ $ }) =>
          $['android:name'] === name &&
          $['android:value'] === `@string/${resource}`
      )
    ) {
      AndroidConfig.Manifest.removeMetaDataItemFromMainApplication(
        application,
        name
      );
    }
  }
  if (android.smallIcon !== undefined) {
    setMetaData(application, ICON, iconResource(android.smallIcon), 'resource');
  }
  const services: Service[] = (application.service ?? []).filter(
    (entry) => !isGenerated(entry)
  );
  if (service !== undefined) {
    // Android resolves ".Name" and "Name" against the app's package.
    const own = services.find(({ $ }) =>
      [service, `.${SERVICE}`, SERVICE].includes($['android:name'])
    );
    if (own !== undefined) {
      throw new Error(
        `${PLUGIN_NAME}: AndroidManifest.xml declares the app's own ${own.$['android:name']}, not the plugin's, so the plugin doesn't replace it. Set android.fcmForwarding to 'none' to keep it, or remove it to use the plugin's.`
      );
    }
    services.push({
      '$': { 'android:name': service, 'android:exported': 'false' },
      'intent-filter': [
        {
          $: { 'android:priority': '1' } as Record<string, string>,
          action: [
            { $: { 'android:name': 'com.google.firebase.MESSAGING_EVENT' } },
          ],
        },
      ],
      'meta-data': [
        { $: { 'android:name': GENERATED, 'android:value': 'true' } },
      ],
    });
  }
  if (services.length > 0) {
    application.service = services;
  } else {
    delete application.service;
  }
  return manifest;
}

/** Writes the string resource of each string option given, as its exact text, and removes those of the others. */
export function setStrings(
  strings: ResourceXML,
  android: AndroidProps
): ResourceXML {
  let result = strings;
  for (const [option, name] of Object.entries(STRINGS)) {
    const value = android[option as keyof typeof STRINGS];
    // Expo's writer escapes no string marked untranslatable, so the value is escaped here.
    result =
      value === undefined
        ? AndroidConfig.Strings.removeStringItem(name, result)
        : AndroidConfig.Strings.setStringItem(
            [
              AndroidConfig.Resources.buildResourceItem({
                name,
                value: XML.escapeAndroidString(String(value)),
                translatable: false,
              }),
            ],
            result
          );
  }
  return result;
}

export const withSallaPushStrings: ConfigPlugin<AndroidProps> = (
  config,
  android
) =>
  withStringsXml(config, (mod) => {
    mod.modResults = setStrings(mod.modResults, android);
    return mod;
  });

export const withSallaPushAndroidManifest: ConfigPlugin<AndroidProps> = (
  config,
  android
) =>
  withAndroidManifest(config, (mod) => {
    const warnings = [
      android.appId === undefined &&
        'android.appId is not set, so on Android SallaPush starts only when JavaScript calls SallaPush.initialize, and processes that FCM starts run without it.' +
          withoutAppId('android', android, WITH_APP_ID),
      mod.android?.googleServicesFile === undefined &&
        'android.googleServicesFile is not set, so Firebase has no configuration and SallaPush gets no FCM token (token.firebase_missing).',
      android.smallIcon === undefined &&
        "android.smallIcon is not set, so SallaPush uses Firebase's default_notification_icon when the app sets one, else its own bell (display.default_icon).",
    ];
    for (const warning of warnings) {
      if (warning) {
        WarningAggregator.addWarningAndroid(PLUGIN_NAME, warning);
      }
    }
    const library = forwardingLibrary(
      android,
      projectDependencies(mod.modRequest.projectRoot)
    );
    mod.modResults = setManifest(
      mod.modResults,
      android,
      library === undefined ? undefined : serviceName(mod)
    );
    return mod;
  });
