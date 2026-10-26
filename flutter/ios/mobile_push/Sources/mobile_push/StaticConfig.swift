import Foundation
import SallaPush

/// The plugin's own Info.plist keys; SallaPush reads its other keys (log level, App Group) itself.
struct StaticConfig: Equatable {
  static let appIdKey = "SallaPushAppId"
  static let openLaunchURLsKey = "SallaPushOpenLaunchURLs"
  static let requiresUserConsentKey = "SallaPushRequiresUserConsent"
  static let clearTagsOnLogoutKey = "SallaPushClearTagsOnLogout"
  static let appVersionKey = "SallaPushAppVersion"
  static let autoClearBadgeKey = "SallaPushAutoClearBadge"
  static let autoUpdateBadgeKey = "SallaPushAutoUpdateBadge"
  static let registerForRemoteNotificationsOnInitKey = "SallaPushRegisterForRemoteNotificationsOnInit"
  static let apnsEnvironmentKey = "SallaPushAPNsEnvironment"

  var appId: String?
  var openLaunchURLs: Bool?
  var requiresUserConsent: Bool?
  var clearTagsOnLogout: Bool?
  var appVersion: String?
  var autoClearBadge: Bool?
  var autoUpdateBadge: Bool?
  var registerForRemoteNotificationsOnInit: Bool?
  var apnsEnvironment: SallaPushAPNsEnvironment?

  func configuration() -> SallaPushConfiguration {
    let configuration = SallaPushConfiguration()
    if let openLaunchURLs { configuration.openLaunchURLs = openLaunchURLs }
    if let requiresUserConsent { configuration.requiresUserConsent = requiresUserConsent }
    if let clearTagsOnLogout { configuration.clearTagsOnLogout = clearTagsOnLogout }
    if let appVersion { configuration.appVersion = appVersion }
    if let autoClearBadge { configuration.autoClearBadge = autoClearBadge }
    if let autoUpdateBadge { configuration.autoUpdateBadge = autoUpdateBadge }
    if let registerForRemoteNotificationsOnInit {
      configuration.registerForRemoteNotificationsOnInit = registerForRemoteNotificationsOnInit
    }
    if let apnsEnvironment { configuration.apnsEnvironment = apnsEnvironment }
    return configuration
  }
}

extension StaticConfig {
  init(infoDictionary: [String: Any], console: Console) {
    let reader = InfoReader(dictionary: infoDictionary, console: console)
    self.init(
      appId: reader.string(Self.appIdKey),
      openLaunchURLs: reader.bool(Self.openLaunchURLsKey),
      requiresUserConsent: reader.bool(Self.requiresUserConsentKey),
      clearTagsOnLogout: reader.bool(Self.clearTagsOnLogoutKey),
      appVersion: reader.string(Self.appVersionKey),
      autoClearBadge: reader.bool(Self.autoClearBadgeKey),
      autoUpdateBadge: reader.bool(Self.autoUpdateBadgeKey),
      registerForRemoteNotificationsOnInit: reader.bool(Self.registerForRemoteNotificationsOnInitKey),
      apnsEnvironment: reader.apnsEnvironment(Self.apnsEnvironmentKey))
  }
}

/// Reads values as plists and xcconfig build settings give them; an unset build setting expands to "".
private struct InfoReader {
  let dictionary: [String: Any]
  let console: Console

  func string(_ key: String) -> String? {
    guard let value = dictionary[key] else { return nil }
    guard let text = value as? String else {
      console.error("Info.plist key \(key) must be a string. It is ignored.")
      return nil
    }
    return Self.trimmed(text)
  }

  func bool(_ key: String) -> Bool? {
    switch dictionary[key] {
    case nil:
      return nil
    case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
      return number.boolValue
    case let text as String:
      guard let trimmed = Self.trimmed(text) else { return nil }
      switch trimmed.lowercased() {
      case "true", "yes", "1":
        return true
      case "false", "no", "0":
        return false
      default:
        console.error("Info.plist key \(key) is \"\(trimmed)\", not YES, NO, true, false, 1 or 0. It is ignored.")
        return nil
      }
    default:
      console.error("Info.plist key \(key) must be a Boolean. It is ignored.")
      return nil
    }
  }

  func apnsEnvironment(_ key: String) -> SallaPushAPNsEnvironment? {
    guard let text = string(key) else { return nil }
    switch text.lowercased() {
    case "automatic":
      return .automatic
    case "sandbox":
      return .sandbox
    case "production":
      return .production
    default:
      console.error("Info.plist key \(key) is \"\(text)\", not automatic, sandbox or production. It is ignored.")
      return nil
    }
  }

  private static func trimmed(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
