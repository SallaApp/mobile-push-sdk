/**
 * Options of the Expo config plugin, set in the app config:
 * `"plugins": [["@salla.sa/mobile-push-react-native", { "ios": { "appId": "…" } }]]`.
 */
export type SallaPushPluginProps = {
  /** The iOS options: the Info.plist keys, the entitlements, the pods and the Notification Service Extension. */
  ios?: {
    /** SallaPushAppId: SallaPush starts natively at launch. Without it, it starts when JavaScript calls initialize. */
    appId?: string;
    /** The aps-environment entitlement, written only when the app has none; 'development' by default. */
    mode?: 'development' | 'production';
    /**
     * An App Group for the app and the extension: the entitlement, and SallaPushAppGroup in both Info.plists. The
     * extension's received events and its count of SallaPush notifications on the app icon's badge need it.
     */
    appGroup?: string;
    /** SallaPushOpenLaunchURLs: SallaPush opens https launch URLs on tap; default false. */
    openLaunchUrls?: boolean;
    /** Requires consent from the first launch, with appId; without it, call SallaPush.setConsentRequired(true) before initialize. */
    requiresUserConsent?: boolean;
    /** SallaPushClearTagsOnLogout: logout and an account switch delete the device's tags; default true. */
    clearTagsOnLogout?: boolean;
    /** SallaPushAutoClearBadge: the app icon's badge goes back to 0 when the app opens; default true. */
    autoClearBadge?: boolean;
    /** SallaPushAutoUpdateBadge: SallaPush counts its notifications on the app icon's badge; default true. */
    autoUpdateBadge?: boolean;
    /** SallaPushRegisterForRemoteNotificationsOnInit: SallaPush registers for remote notifications; default true. */
    registerForRemoteNotificationsOnInit?: boolean;
    /** SallaPushAPNsEnvironment; default automatic, read from the provisioning profile. */
    apnsEnvironment?: 'automatic' | 'sandbox' | 'production';
    /** SallaPushAppVersion: the app version SallaPush reports; default the app's version. */
    appVersion?: string;
    /** SallaPushLogLevel: the console log level; default warn. */
    logLevel?: 'off' | 'error' | 'warn' | 'info' | 'debug' | 'verbose';
    /** Adds the Notification Service Extension SallaPushNotificationService, for images and delivery events; default true. */
    notificationServiceExtension?: boolean;
    /** The extension's DEVELOPMENT_TEAM; ios.appleTeamId by default. */
    developmentTeam?: string;
  };
  /** The Android options: the manifest's meta-data, the notification icon and the FCM forwarding service. */
  android?: {
    /** com.salla.push.APP_ID: SallaPush starts natively whenever the app's main process starts. Without it, it starts when JavaScript calls initialize. */
    appId?: string;
    /** A 96×96 white-on-transparent PNG such as './assets/notification-icon.png' (copied), or '@drawable/name'; without it, Firebase's default icon, else SallaPush's bell. */
    smallIcon?: string;
    /** com.salla.push.default_channel_id: the channel SallaPush's notifications use; without it, Firebase's default channel when it exists, else SallaPush's own. */
    defaultChannelId?: string;
    /** com.salla.push.default_channel_name: that channel's name, when SallaPush creates it. */
    defaultChannelName?: string;
    /** com.salla.push.OPEN_LAUNCH_URLS: SallaPush opens https launch URLs on tap; default false. */
    openLaunchUrls?: boolean;
    /** Requires consent from the first launch, with appId; without it, call SallaPush.setConsentRequired(true) before initialize. */
    requiresUserConsent?: boolean;
    /** com.salla.push.CLEAR_TAGS_ON_LOGOUT: logout and an account switch delete the device's tags; default true. */
    clearTagsOnLogout?: boolean;
    /**
     * com.salla.push.AUTO_CLEAR_BADGE: SallaPush removes its notifications that show on the app icon's badge when the
     * app comes to the foreground; default false.
     */
    autoClearBadge?: boolean;
    /** com.salla.push.AUTO_UPDATE_BADGE: SallaPush creates its notification channels with badges; default true. */
    autoUpdateBadge?: boolean;
    /** com.salla.push.APP_VERSION: the app version SallaPush reports; default the app's version. */
    appVersion?: string;
    /** com.salla.push.LOG_LEVEL: the console log level; default warn. */
    logLevel?: 'off' | 'error' | 'warn' | 'info' | 'debug' | 'verbose';
    /**
     * com.salla.push.DISPLAY_COMPAT_PAYLOADS: SallaPush shows its compat-format notifications; default true. Set it to
     * false when another SDK in the app shows them already.
     */
    displayCompatPayloads?: boolean;
    /**
     * The library whose FCM service the generated SallaPushMessagingService extends, so FCM reaches SallaPush first;
     * 'auto' (the default) picks the one in package.json, and 'none' generates nothing.
     */
    fcmForwarding?:
      | 'auto'
      | 'none'
      | 'expo-notifications'
      | '@react-native-firebase/messaging';
  };
};
