import KataCore
import SwiftUI

public extension Tone {
  var color: Color {
    switch self {
    case .positive: .green
    case .negative: .red
    case .warning: .orange
    case .info: .blue
    }
  }

  var symbolName: String {
    switch self {
    case .positive: "checkmark.circle.fill"
    case .negative: "xmark.octagon.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .info: "info.circle.fill"
    }
  }

  var label: String {
    switch self {
    case .positive: "Good"
    case .negative: "Avoid"
    case .warning: "Caution"
    case .info: "Note"
    }
  }
}
