import CoreGraphics
import Foundation

/// Monospaced text measurements, injected so layout stays deterministic and UI-free.
public struct TextMetrics: Sendable, Equatable {
  public var charWidth: CGFloat
  public var lineHeight: CGFloat

  public init(charWidth: CGFloat, lineHeight: CGFloat) {
    self.charWidth = charWidth
    self.lineHeight = lineHeight
  }

  /// Approximation for the 14 pt system monospaced font (the app's default diagram size).
  public static let `default` = TextMetrics(charWidth: 8.4, lineHeight: 17)

  public func width(of text: String) -> CGFloat {
    CGFloat(text.count) * charWidth
  }
}
