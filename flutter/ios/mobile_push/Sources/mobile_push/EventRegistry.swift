import Foundation

/// The events that have one native registration each, made while Dart listens to their stream.
enum EventKind: CaseIterable {
  case click
  case willDisplay
  case permission
  case user
  case loginFailure
  case log
}

/// The native listeners behind the Dart event streams, and the sinks of those streams while Dart listens.
///
/// A kind has one native registration while Dart listens to it, so taps made before that stay queued natively, and
/// foreground notifications are held for Dart's decision only while Dart listens for them. Each Dart push-subscription
/// listener has its own native observer, so it gets SallaPush's own replay. Main thread only.
final class EventRegistry {
  var clickSink: PigeonEventSink<ClickEventMessage>?
  var willDisplaySink: PigeonEventSink<WillDisplayEventMessage>?
  var permissionSink: PigeonEventSink<PermissionChangeMessage>?
  var userSink: PigeonEventSink<UserChangedMessage>?
  var loginFailureSink: PigeonEventSink<LoginFailureEventMessage>?
  var pushSubscriptionSink: PigeonEventSink<SubscriptionChangedMessage>?
  var logSink: PigeonEventSink<LogEntryMessage>?

  private let native: NativeSallaPush
  private let displays: DisplayStore
  private let mainQueue: (@escaping () -> Void) -> Void
  private var registrations: [EventKind: NativeObservation] = [:]
  private var subscriptionObservers: [Int64: NativeObservation] = [:]
  private var logLevel = SallaPushLogLevel.warn

  /// - Parameter mainQueue: runs a block on the main thread, later.
  init(
    native: NativeSallaPush, displays: DisplayStore,
    mainQueue: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
  ) {
    self.native = native
    self.displays = displays
    self.mainQueue = mainQueue
  }

  /// Registers the native listener of `kind`, unless it is registered.
  func start(_ kind: EventKind) {
    guard registrations[kind] == nil else { return }
    registrations[kind] = register(kind)
  }

  /// Cancels the native listener of `kind`, if any.
  func stop(_ kind: EventKind) {
    registrations.removeValue(forKey: kind)?.cancel()
  }

  /// Sets the level of the native log handler: for its next registration, and at once while Dart listens to logs.
  func setLogLevel(_ level: SallaPushLogLevel) {
    guard level != logLevel else { return }
    logLevel = level
    guard let previous = registrations[.log] else { return }
    registrations[.log] = register(.log)
    previous.cancel()
  }

  /// Adds the native observer of the Dart push-subscription listener `id`, unless it exists.
  func addSubscriptionListener(_ id: Int64) {
    guard subscriptionObservers[id] == nil else { return }
    subscriptionObservers[id] = native.addPushSubscriptionObserver { [weak self] previous, current in
      self?.pushSubscriptionSink?.success(
        SubscriptionChangedMessage(listenerId: id, previous: previous, current: current))
    }
  }

  /// Removes the native observer of the Dart push-subscription listener `id`, if any.
  func removeSubscriptionListener(_ id: Int64) {
    subscriptionObservers.removeValue(forKey: id)?.cancel()
  }

  /// Removes the native observer of every Dart push-subscription listener.
  func removeSubscriptionListeners() {
    let observers = subscriptionObservers
    subscriptionObservers = [:]
    observers.values.forEach { $0.cancel() }
  }

  /// Cancels every native registration and forgets the sinks: the engine is going away.
  func stopAll() {
    for kind in EventKind.allCases {
      stop(kind)
    }
    removeSubscriptionListeners()
    clickSink = nil
    willDisplaySink = nil
    permissionSink = nil
    userSink = nil
    loginFailureSink = nil
    pushSubscriptionSink = nil
    logSink = nil
  }

  // SallaPush keeps the handlers until they are cancelled, so they capture the registry weakly.
  private func register(_ kind: EventKind) -> NativeObservation {
    switch kind {
    case .click:
      return native.addClickListener { [weak self] event in
        self?.clickSink?.success(event)
      }
    case .willDisplay:
      // SallaPush decides when this returns: the notification is held here, and Dart shows it unless it prevents it.
      return native.addForegroundLifecycleListener { [weak self] event in
        guard let self, let sink = self.willDisplaySink else { return }
        event.preventDefault()
        sink.success(WillDisplayEventMessage(handle: self.displays.put(event.display), notification: event.message))
      }
    case .permission:
      return native.addPermissionObserver { [weak self] permission in
        self?.permissionSink?.success(PermissionChangeMessage(permission: permission))
      }
    case .user:
      return native.addUserObserver { [weak self] change in
        self?.userSink?.success(change)
      }
    case .loginFailure:
      return native.addLoginFailureHandler { [weak self] failure in
        self?.loginFailureSink?.success(LoginFailureEventMessage(failure: failure))
      }
    case .log:
      // SallaPush logs on its own queue, and Flutter takes events on the main thread only.
      let mainQueue = self.mainQueue
      return native.addLogHandler(level: logLevel) { [weak self] entry in
        mainQueue { self?.logSink?.success(entry) }
      }
    }
  }
}
