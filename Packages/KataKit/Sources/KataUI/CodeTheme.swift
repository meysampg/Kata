import KataCode
import SwiftUI

/// Muted, Xcode-like syntax palettes for light and dark appearance.
public struct CodeTheme: Sendable, Equatable {
  /// 0xRRGGBB per token kind.
  public let palette: [TokenKind: UInt32]
  public let isDark: Bool

  public init(isDark: Bool, palette: [TokenKind: UInt32]) {
    self.isDark = isDark
    self.palette = palette
  }

  public static let light = CodeTheme(
    isDark: false,
    palette: [
      .keyword: 0x9B2393, .type: 0x3E8087, .function: 0x326D74, .identifier: 0x1F1F24,
      .annotation: 0x836C28, .string: 0xC41A16, .number: 0x1C00CF, .comment: 0x6C7986,
      .docComment: 0x5D6C79, .operator: 0x3B3B40, .punctuation: 0x3B3B40, .whitespace: 0x1F1F24,
    ])

  public static let dark = CodeTheme(
    isDark: true,
    palette: [
      .keyword: 0xFC5FA3, .type: 0x5DD8FF, .function: 0x67B7A4, .identifier: 0xDFDFE0,
      .annotation: 0xD0A8FF, .string: 0xFC6A5D, .number: 0xD0BF69, .comment: 0x7F8C98,
      .docComment: 0x8A99A6, .operator: 0xC8C8CC, .punctuation: 0xC8C8CC, .whitespace: 0xDFDFE0,
    ])

  public static func theme(for scheme: ColorScheme) -> CodeTheme { scheme == .dark ? .dark : .light }

  public func rgb(for kind: TokenKind) -> UInt32 { palette[kind] ?? 0x808080 }

  public func color(for kind: TokenKind) -> Color {
    let v = rgb(for: kind)
    return Color(
      red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255)
  }

  /// Colour for the line-number gutter.
  public var gutterColor: Color { isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35) }
}
