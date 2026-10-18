import Foundation
import KataCore

enum AppTab: Hashable, Sendable {
  case today, path, library, search
}

/// Pushes an item's deck onto a navigation stack, optionally at a given card role.
struct DeckRoute: Hashable, Sendable {
  let key: ItemKey
  var role: String?
}

/// What a practice session is made of.
struct PracticeRequest: Identifiable {
  enum Kind {
    /// Due reviews (plus new exercises of studied items), built by `PracticeQueueBuilder`.
    case review
    /// First-exposure / extra practice: every exercise of one item.
    case item(ItemKey)
  }

  let id = UUID()
  let kind: Kind
}
