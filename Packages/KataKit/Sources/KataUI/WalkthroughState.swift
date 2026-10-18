import Foundation
import KataCore

/// Pure state for stepping through a code card's walkthrough.
public struct WalkthroughState: Sendable, Equatable {
  public struct Step: Sendable, Equatable {
    /// 1-based inclusive line range.
    public var lines: ClosedRange<Int>
    public var note: String
    public init(lines: ClosedRange<Int>, note: String) { self.lines = lines; self.note = note }
  }

  public private(set) var steps: [Step]
  public private(set) var index: Int

  public init(steps: [Step], index: Int = 0) {
    self.steps = steps
    self.index = steps.isEmpty ? 0 : min(max(index, 0), steps.count - 1)
  }

  /// Resolves each step's region name against the card; unknown regions are skipped.
  public init(card: CodeCard) {
    self.init(
      steps: card.walkthrough.compactMap { s in
        card.regions[s.region].map { Step(lines: $0.lines, note: s.note) }
      })
  }

  public var isEmpty: Bool { steps.isEmpty }
  public var current: Step? { steps.isEmpty ? nil : steps[index] }
  public var canGoPrevious: Bool { index > 0 }
  public var canGoNext: Bool { index < steps.count - 1 }
  /// "step 2 of 6"
  public var progressText: String { steps.isEmpty ? "" : "step \(index + 1) of \(steps.count)" }

  public mutating func next() { if canGoNext { index += 1 } }
  public mutating func previous() { if canGoPrevious { index -= 1 } }
  public mutating func go(to i: Int) { if !steps.isEmpty { index = min(max(i, 0), steps.count - 1) } }
  public mutating func reset() { index = 0 }
}
