import os

/// The plugin's own console lines, prefixed [SallaPush].
struct Console {
  var info: (String) -> Void
  var error: (String) -> Void

  static let live: Console = {
    let logger = os.Logger(subsystem: "com.salla.push", category: "wrapper")
    return Console(
      info: { logger.info("[SallaPush] \($0, privacy: .public)") },
      error: { logger.error("[SallaPush] \($0, privacy: .public)") })
  }()
}

/// Calls to members that work on the other platform only, each reported once per process.
final class PlatformOnlyCalls {
  static let shared = PlatformOnlyCalls()

  private var reported: Set<String> = []

  /// True the first time `member` is passed in this process. Called on the main thread.
  func isFirst(_ member: String) -> Bool {
    reported.insert(member).inserted
  }
}
