import KataDiagram
import SwiftUI
import Synchronization

/// Measures the real monospaced system font once per size.
enum MonoMetrics {
  private static let cache = Mutex<[CGFloat: TextMetrics]>([:])

  static func metrics(size: CGFloat, weight: PlatformFont.Weight = .regular) -> TextMetrics {
    let key = size * 10 + (weight == .regular ? 0 : 1)
    if let m = cache.withLock({ $0[key] }) { return m }
    let font = PlatformFont.monospacedSystemFont(ofSize: size, weight: weight)
    let w = ("M" as NSString).size(withAttributes: [.font: font]).width
    let m = TextMetrics(charWidth: w, lineHeight: ceil(font.kataLineHeight))
    cache.withLock { $0[key] = m }
    return m
  }
}
