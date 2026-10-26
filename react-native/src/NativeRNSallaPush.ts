import {
  TurboModuleRegistry,
  type CodegenTypes,
  type TurboModule,
} from 'react-native';

export type ConfigSpec = {
  logLevel?: string;
  appVersion?: string;
  clearTagsOnLogout?: boolean;
  requiresUserConsent?: boolean;
  openLaunchUrls?: boolean;
  autoClearBadge?: boolean;
  autoUpdateBadge?: boolean;
  iosAppGroupIdentifier?: string;
  iosApnsEnvironment?: string;
  iosRegisterForRemoteNotificationsOnInit?: boolean;
};

export type NotificationSpec = {
  notificationId?: string;
  title?: string;
  subtitle?: string;
  body?: string;
  imageUrl?: string;
  launchUrl?: string;
  additionalData: Object;
  rawPayload: Object;
  source: string;
  // The non-null results of native's typed accessors for each top-level additionalData key.
  stringValues: Object;
  intValues: Object;
  boolValues: Object;
  numberValues: Object;
  sound?: string;
  badge?: number;
  threadId?: string;
  androidNotificationId?: number;
  collapseId?: string;
  channelId?: string;
};
export type ClickEventSpec = {
  notification: NotificationSpec;
  actionId?: string;
  url?: string;
};
export type WillDisplayEventSpec = {
  handle: string;
  notification: NotificationSpec;
};
export type PermissionChangeSpec = { permission: boolean };
export type SubscriptionStateSpec = {
  id?: string;
  token?: string;
  optedIn: boolean;
};
export type SubscriptionChangedSpec = {
  listenerId: number;
  previous: SubscriptionStateSpec;
  current: SubscriptionStateSpec;
};
export type UserStateSpec = { externalId?: string; isLoggedIn: boolean };
export type UserChangedSpec = {
  previous: UserStateSpec;
  current: UserStateSpec;
};
export type LoginFailureSpec = { failure: string };
export type LogEntrySpec = {
  level: string;
  category: string;
  code: string;
  message: string;
  metadata: Object;
  timestamp: number;
};

export interface Spec extends TurboModule {
  initWithAppId(appId: string, config: ConfigSpec): void;
  isInitialized(): Promise<boolean>;
  getAppId(): Promise<string | null>;
  getSdkVersion(): Promise<string>;
  setConsentRequired(required: boolean): void;
  setConsentGiven(given: boolean): void;
  login(externalId: string, identityToken: string): void;
  logout(): void;

  getExternalId(): Promise<string | null>;
  isLoggedIn(): Promise<boolean>;
  addTag(key: string, value: string): void;
  addTags(tags: Object): void;
  removeTag(key: string): void;
  removeTags(keys: Array<string>): void;
  getTags(): Promise<Object>;
  setLanguage(language: string | null): void;

  getPushSubscriptionId(): Promise<string | null>;
  getPushSubscriptionToken(): Promise<string | null>;
  getPushSubscriptionOptedIn(): Promise<boolean>;
  optIn(): void;
  optOut(): void;
  addPushSubscriptionListener(listenerId: number): void;
  removePushSubscriptionListener(listenerId: number): void;

  getPermission(): Promise<boolean>;
  canRequestPermission(): Promise<boolean>;
  getPermissionStatus(): Promise<string | null>;
  requestPermission(fallbackToSettings: boolean): Promise<boolean>;
  registerForProvisionalAuthorization(): Promise<boolean>;
  refreshPermission(): void;
  registerForRemoteNotifications(): void;
  forwardApnsToken(apnsToken: string): void;
  clearAll(): void;
  removeNotification(androidNotificationId: number): void;
  isSallaPushNotification(payload: Object): Promise<boolean>;
  trackOpened(additionalData: Object | null): Promise<boolean>;
  displayNotification(handle: string): void;

  setDisplayCompatPayloads(display: boolean): void;

  getLogLevel(): Promise<string>;
  setLogLevel(level: string): void;
  setLogHandlerLevel(level: string): void;

  startEvents(kind: string): void;
  stopEvents(kind: string): void;

  readonly onClick: CodegenTypes.EventEmitter<ClickEventSpec>;
  readonly onWillDisplay: CodegenTypes.EventEmitter<WillDisplayEventSpec>;
  readonly onPermissionChange: CodegenTypes.EventEmitter<PermissionChangeSpec>;
  readonly onUserChange: CodegenTypes.EventEmitter<UserChangedSpec>;
  readonly onLoginFailure: CodegenTypes.EventEmitter<LoginFailureSpec>;
  readonly onPushSubscriptionChange: CodegenTypes.EventEmitter<SubscriptionChangedSpec>;
  readonly onLog: CodegenTypes.EventEmitter<LogEntrySpec>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RNSallaPush');
