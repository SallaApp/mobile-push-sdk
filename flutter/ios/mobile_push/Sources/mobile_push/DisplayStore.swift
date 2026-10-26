import Foundation

/// The foreground notifications that Dart may still show, each under a random handle, because SallaPush shows only the
/// very notification it offered. Main thread only.
final class DisplayStore {
  /// SallaPush's own display window, in seconds.
  static let lifetime: TimeInterval = 600
  /// SallaPush's own record limit: older notifications can no longer be shown.
  static let capacity = 20

  private struct Entry {
    let handle: String
    let display: () -> Void
    let createdAt: TimeInterval
  }

  let now: () -> TimeInterval
  private var entries: [Entry] = []

  /// - Parameter now: the wall clock, in seconds since 1970, which SallaPush's own display window uses.
  init(now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }) {
    self.now = now
  }

  /// Keeps `display`, which shows the original notification, and returns its new handle. The oldest entry goes when
  /// the store is full.
  func put(_ display: @escaping () -> Void) -> String {
    removeExpired()
    let handle = UUID().uuidString
    entries.append(Entry(handle: handle, display: display, createdAt: now()))
    if entries.count > Self.capacity {
      entries.removeFirst(entries.count - Self.capacity)
    }
    return handle
  }

  /// Shows the notification held under `handle` and forgets it; false for an unknown or expired handle.
  func display(_ handle: String) -> Bool {
    removeExpired()
    guard let index = entries.firstIndex(where: { $0.handle == handle }) else { return false }
    entries.remove(at: index).display()
    return true
  }

  func clear() {
    entries.removeAll()
  }

  private func removeExpired() {
    let now = self.now()
    entries.removeAll { now - $0.createdAt > Self.lifetime }
  }
}
