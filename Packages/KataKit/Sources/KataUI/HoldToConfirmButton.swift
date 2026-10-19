import SwiftUI

/// A destructive-action button that must be held to fire. VoiceOver users activate it directly.
public struct HoldToConfirmButton: View {
  let title: LocalizedStringKey
  let duration: Double
  let onConfirm: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var progress: CGFloat = 0
  @State private var isPressing = false
  @State private var confirmCount = 0
  @State private var didConfirm = false

  public init(_ title: LocalizedStringKey, duration: Double = 1.2, onConfirm: @escaping () -> Void) {
    self.title = title; self.duration = duration; self.onConfirm = onConfirm
  }

  public var body: some View {
    Text(title)
      .font(.body.weight(.semibold))
      .foregroundStyle(.red)
      .frame(maxWidth: .infinity, minHeight: 48)
      .background {
        GeometryReader { g in
          ZStack(alignment: .leading) {
            Color.red.opacity(0.10)
            Color.red.opacity(0.28).frame(width: g.size.width * progress)
          }
        }
        .clipShape(.capsule)
      }
      .scaleEffect(isPressing && !reduceMotion ? 0.98 : 1)
      .contentShape(.capsule)
      .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
        confirm()
      } onPressingChanged: { pressing in
        pressingChanged(pressing)
      }
      .sensoryFeedback(.impact(weight: .medium), trigger: isPressing) { _, now in now }
      .sensoryFeedback(.success, trigger: confirmCount)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(title))
      .accessibilityHint("Press and hold to confirm")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { confirm() }
  }

  private func pressingChanged(_ pressing: Bool) {
    isPressing = pressing
    if pressing {
      didConfirm = false
      var reset = Transaction(); reset.disablesAnimations = true
      withTransaction(reset) { progress = 0 }
      withAnimation(reduceMotion ? nil : .linear(duration: duration)) { progress = 1 }
    } else if !didConfirm {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { progress = 0 }
    }
  }

  private func confirm() {
    guard !didConfirm else { return }
    didConfirm = true
    confirmCount += 1
    progress = 1
    onConfirm()
  }
}

#Preview("HoldToConfirm") {
  HoldToConfirmButton("Hold to reset progress") {}.padding()
}
