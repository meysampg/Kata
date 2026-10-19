import KataCore
import KataSRS
import SwiftUI

/// One labelled paragraph of feedback ("You chose", "Why", ...).
public struct FeedbackLine: Identifiable {
  public let id = UUID()
  public var label: String?
  public var text: String
  public init(label: String? = nil, text: String) { self.label = label; self.text = text }
}

/// Floating panel under an exercise after it was answered. Wrong answers continue as Again;
/// right answers continue as the suggested rating, with optional Hard / Easy adjustments.
public struct FeedbackPanel: View {
  let isCorrect: Bool
  let headline: String
  let lines: [FeedbackLine]
  let suggested: Rating
  let previews: [Rating: SchedulingResult]
  let now: Date
  let onRate: (Rating) -> Void

  @Environment(\.dynamicTypeSize) private var typeSize
  #if os(macOS)
  @State private var contentHeight: CGFloat = 0
  #endif

  public init(
    isCorrect: Bool, headline: String, lines: [FeedbackLine], suggested: Rating,
    previews: [Rating: SchedulingResult], now: Date, onRate: @escaping (Rating) -> Void
  ) {
    self.isCorrect = isCorrect; self.headline = headline; self.lines = lines
    self.suggested = suggested; self.previews = previews; self.now = now; self.onRate = onRate
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
          .foregroundStyle(isCorrect ? .green : .red)
          .accessibilityHidden(true)
        Text(headline).font(.headline)
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(lines) { line in
            VStack(alignment: .leading, spacing: 2) {
              if let label = line.label {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
              }
              Text(InlineMarkdown.attributed(line.text)).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(macOS)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        #endif
      }
      #if os(macOS)
      // A macOS ScrollView takes all the height it is offered; fit it to its text instead.
      .frame(height: min(contentHeight, typeSize.isAccessibilitySize ? 220 : 170))
      #else
      .frame(maxHeight: typeSize.isAccessibilitySize ? 220 : 170)
      #endif
      .scrollBounceBehavior(.basedOnSize)

      GlassEffectContainer(spacing: 8) {
        HStack(spacing: 8) {
          if isCorrect {
            adjust(.hard)
          }
          Button { onRate(suggested) } label: {
            VStack(spacing: 1) {
              Text("Continue").font(.body.weight(.semibold))
              if let p = previews[suggested] {
                Text(IntervalFormatter.short(p, from: now)).font(.caption2)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.glassProminent)
          .tint(isCorrect ? .green : .red)
          .keyboardShortcut(.defaultAction)
          if isCorrect {
            adjust(.easy)
          }
        }
      }
    }
    .padding(16)
    .glassEffect(.regular, in: .rect(cornerRadius: 26))
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
  }

  private func adjust(_ rating: Rating) -> some View {
    Button { onRate(rating) } label: {
      VStack(spacing: 1) {
        Text(rating.title).font(.callout)
        if let p = previews[rating] { Text(IntervalFormatter.short(p, from: now)).font(.caption2) }
      }
      .frame(minWidth: 64, minHeight: 44)
    }
    .buttonStyle(.glass)
    .tint(rating.tint)
  }
}

/// Builds the feedback paragraphs for an answered exercise.
public enum FeedbackLines {
  /// - Parameter title: resolves an option's `ref` to a display title.
  public static func make(
    for exercise: Exercise, grade: GradeResult, title: (ItemID) -> String
  ) -> [FeedbackLine] {
    let f = grade.feedback
    var out: [FeedbackLine] = []
    switch exercise.body {
    case .identify(_, let options), .choose(_, let options):
      let correctTitle = options.first(where: \.correct).map { o in
        o.ref.map(title) ?? o.text ?? ""
      }
      if grade.correct {
        if let why = f.correctWhy { out.append(FeedbackLine(text: why)) }
      } else {
        if let why = f.chosenWhy { out.append(FeedbackLine(label: "Your answer", text: why)) }
        if let why = f.correctWhy {
          out.append(FeedbackLine(label: "Correct answer: \(correctTitle ?? "")", text: why))
        }
      }
    case .tapLine, .reorder:
      if let e = f.explanation { out.append(FeedbackLine(text: e)) }
    case .recall:
      if !f.missedPoints.isEmpty {
        out.append(FeedbackLine(label: "Missed", text: f.missedPoints.joined(separator: "\n")))
      }
    }
    return out
  }
}
