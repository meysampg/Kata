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

  /// Approximation for the 12 pt system monospaced font.
  public static let `default` = TextMetrics(charWidth: 7.2, lineHeight: 15)

  public func width(of text: String) -> CGFloat {
    CGFloat(text.count) * charWidth
  }
}
