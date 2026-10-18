#if os(iOS)
import KataDiagram
import UIKit

/// Measures the real monospaced system font once per size.
@MainActor
enum MonoMetrics {
  private static var cache: [CGFloat: TextMetrics] = [:]

  static func metrics(size: CGFloat, weight: UIFont.Weight = .regular) -> TextMetrics {
    let key = size * 10 + (weight == .regular ? 0 : 1)
    if let m = cache[key] { return m }
    let font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    let w = ("M" as NSString).size(withAttributes: [.font: font]).width
    let m = TextMetrics(charWidth: w, lineHeight: ceil(font.lineHeight))
    cache[key] = m
    return m
  }
}
#endif
