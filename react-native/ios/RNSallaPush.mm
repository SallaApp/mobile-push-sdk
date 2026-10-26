#import "RNSallaPush.h"

#import <React/RCTInvalidating.h>

#if __has_include(<SallaPushReactNative/SallaPushReactNative-Swift.h>)
#import <SallaPushReactNative/SallaPushReactNative-Swift.h>
#else
#import "SallaPushReactNative-Swift.h"
#endif

// SallaPushEventEmitter's methods are the codegen emitters NativeRNSallaPushSpecBase implements.
@interface RNSallaPush () <SallaPushEventEmitter, RCTInvalidating>

@end

// A nil result would reach JavaScript as undefined; the API resolves null.
static id orNull(id value)
{
  return value ?: (id)kCFNull;
}

static NSNumber *boolOrNil(std::optional<bool> value)
{
  return value.has_value() ? @(value.value()) : nil;
}

@implementation RNSallaPush {
  SallaPushBridge *_bridge;
}

- (instancetype)init
{
  if (self = [super init]) {
    _bridge = [[SallaPushBridge alloc] initWithEmitter:self];
  }
  return self;
}

+ (NSString *)moduleName
{
  return @"RNSallaPush";
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// SallaPush calls back on the main thread, so the module's calls run there too, in call order.
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeRNSallaPushSpecJSI>(params);
}

- (void)initWithAppId:(NSString *)appId config:(JS::NativeRNSallaPush::ConfigSpec &)config
{
  NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary new];
  options[@"logLevel"] = config.logLevel();
  options[@"appVersion"] = config.appVersion();
  options[@"clearTagsOnLogout"] = boolOrNil(config.clearTagsOnLogout());
  options[@"requiresUserConsent"] = boolOrNil(config.requiresUserConsent());
  options[@"openLaunchUrls"] = boolOrNil(config.openLaunchUrls());
  options[@"autoClearBadge"] = boolOrNil(config.autoClearBadge());
  options[@"autoUpdateBadge"] = boolOrNil(config.autoUpdateBadge());
  options[@"iosAppGroupIdentifier"] = config.iosAppGroupIdentifier();
  options[@"iosApnsEnvironment"] = config.iosApnsEnvironment();
  options[@"iosRegisterForRemoteNotificationsOnInit"] = boolOrNil(config.iosRegisterForRemoteNotificationsOnInit());
  [_bridge initializeWithAppId:appId options:options];
}

- (void)isInitialized:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@(_bridge.isInitialized));
}

- (void)getAppId:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(orNull(_bridge.appId));
}

- (void)getSdkVersion:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(_bridge.sdkVersion);
}

- (void)setConsentRequired:(BOOL)required
{
  [_bridge setConsentRequired:required];
}

- (void)setConsentGiven:(BOOL)given
{
  [_bridge setConsentGiven:given];
}

- (void)login:(NSString *)externalId identityToken:(NSString *)identityToken
{
  [_bridge loginWithExternalId:externalId identityToken:identityToken];
}

- (void)logout
{
  [_bridge logout];
}

- (void)getExternalId:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(orNull(_bridge.externalId));
}

- (void)isLoggedIn:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@(_bridge.isLoggedIn));
}

- (void)addTag:(NSString *)key value:(NSString *)value
{
  [_bridge addTagWithKey:key value:value];
}

- (void)addTags:(NSDictionary *)tags
{
  [_bridge addTags:tags];
}

- (void)removeTag:(NSString *)key
{
  [_bridge removeTag:key];
}

- (void)removeTags:(NSArray *)keys
{
  [_bridge removeTags:keys];
}

- (void)getTags:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(_bridge.tags);
}

- (void)setLanguage:(NSString *_Nullable)language
{
  [_bridge setLanguage:language];
}

- (void)getPushSubscriptionId:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(orNull(_bridge.pushSubscriptionId));
}

- (void)getPushSubscriptionToken:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(orNull(_bridge.pushSubscriptionToken));
}

- (void)getPushSubscriptionOptedIn:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@(_bridge.pushSubscriptionOptedIn));
}

- (void)optIn
{
  [_bridge optIn];
}

- (void)optOut
{
  [_bridge optOut];
}

- (void)addPushSubscriptionListener:(double)listenerId
{
  [_bridge addPushSubscriptionListener:(NSInteger)listenerId];
}

- (void)removePushSubscriptionListener:(double)listenerId
{
  [_bridge removePushSubscriptionListener:(NSInteger)listenerId];
}

- (void)getPermission:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@(_bridge.permission));
}

- (void)canRequestPermission:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@(_bridge.canRequestPermission));
}

- (void)getPermissionStatus:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(_bridge.permissionStatus);
}

- (void)requestPermission:(BOOL)fallbackToSettings
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject
{
  [_bridge requestPermissionWithFallbackToSettings:fallbackToSettings
                                        completion:^(BOOL granted) {
                                          resolve(@(granted));
                                        }];
}

- (void)registerForProvisionalAuthorization:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_bridge registerForProvisionalAuthorizationWithCompletion:^(BOOL granted) {
    resolve(@(granted));
  }];
}

- (void)refreshPermission
{
  [_bridge refreshPermission];
}

- (void)registerForRemoteNotifications
{
  [_bridge registerForRemoteNotifications];
}

- (void)forwardApnsToken:(NSString *)apnsToken
{
  [_bridge forwardApnsToken:apnsToken];
}

- (void)clearAll
{
  [_bridge clearAll];
}

- (void)removeNotification:(double)androidNotificationId
{
  [_bridge removeNotification];
}

- (void)isSallaPushNotification:(NSDictionary *)payload
                        resolve:(RCTPromiseResolveBlock)resolve
                         reject:(RCTPromiseRejectBlock)reject
{
  resolve(@([_bridge isSallaPushNotification:payload]));
}

- (void)trackOpened:(NSDictionary *_Nullable)additionalData
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject
{
  resolve(@([_bridge trackOpened]));
}

- (void)displayNotification:(NSString *)handle
{
  [_bridge displayNotification:handle];
}

- (void)setDisplayCompatPayloads:(BOOL)display
{
  [_bridge setDisplayCompatPayloads];
}

- (void)getLogLevel:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(_bridge.logLevel);
}

- (void)setLogLevel:(NSString *)level
{
  _bridge.logLevel = level;
}

- (void)setLogHandlerLevel:(NSString *)level
{
  [_bridge setLogHandlerLevel:level];
}

- (void)startEvents:(NSString *)kind
{
  [_bridge startEvents:kind];
}

- (void)stopEvents:(NSString *)kind
{
  [_bridge stopEvents:kind];
}

// React Native calls it on the method queue when the JavaScript runtime goes away.
- (void)invalidate
{
  [_bridge invalidate];
}

@end
