import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#endif

extension Color {
  /// The system's secondary grouped background (iOS) or control background (macOS).
  static var kataSecondaryBackground: Color {
    #if canImport(UIKit)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color(nsColor: .controlBackgroundColor)
    #endif
  }
}

extension PlatformFont {
  /// Line height of the font: `lineHeight` on iOS, ascender - descender + leading on macOS.
  var kataLineHeight: CGFloat {
    #if canImport(UIKit)
    lineHeight
    #else
    ascender - descender + leading
    #endif
  }
}
