import Foundation
import KataCode
import KataSRS
import Testing
@testable import KataUI

@Suite struct KataUITests {
  @Test func themeCoversAllTokenKinds() {
    for theme in [CodeTheme.light, CodeTheme.dark] {
      for kind in TokenKind.allCases { #expect(theme.palette[kind] != nil, "\(kind)") }
    }
    #expect(CodeTheme.light.rgb(for: .keyword) != CodeTheme.dark.rgb(for: .keyword))
  }

  @Test func walkthroughNavigation() {
    var s = WalkthroughState(steps: [
      .init(lines: 1...2, note: "a"), .init(lines: 4...4, note: "b"), .init(lines: 6...9, note: "c"),
    ])
    #expect(s.progressText == "step 1 of 3")
    #expect(!s.canGoPrevious && s.canGoNext)
    s.previous(); #expect(s.index == 0)
    s.next(); s.next(); s.next()
    #expect(s.index == 2 && s.current?.note == "c" && !s.canGoNext)
    #expect(s.progressText == "step 3 of 3")
    s.go(to: 99); #expect(s.index == 2)
    s.reset(); #expect(s.index == 0)
    let empty = WalkthroughState(steps: [])
    #expect(empty.isEmpty && empty.current == nil && empty.progressText == "")
  }

  @Test func intervalFormatting() {
    #expect(IntervalFormatter.short(seconds: 600, scheduledDays: 0) == "10 min")
    #expect(IntervalFormatter.short(seconds: 3 * 3600, scheduledDays: 0) == "3 h")
    #expect(IntervalFormatter.short(seconds: 0, scheduledDays: 0) == "1 min")
    #expect(IntervalFormatter.short(seconds: 0, scheduledDays: 5) == "5 d")
    #expect(IntervalFormatter.short(seconds: 0, scheduledDays: 60) == "2 mo")
    #expect(IntervalFormatter.short(seconds: 0, scheduledDays: 438) == "1.2 y")
    #expect(IntervalFormatter.short(seconds: 0, scheduledDays: 730) == "2 y")
  }

  @Test func inlineMarkdown() {
    let a = InlineMarkdown.attributed("a **b** `c` [x](kata:strategy)")
    #expect(String(a.characters) == "a b c x")
    #expect(a.runs.contains { $0.link?.scheme == "kata" })
  }
}
