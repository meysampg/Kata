import Foundation
import KataCore
import KataStore

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
  typealias Kind = PracticeSessionModel.Kind

  let id = UUID()
  let kind: Kind
}
