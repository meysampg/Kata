import Foundation
import KataCore
import KataStore
import Testing

@testable import Kata

struct BundledPackSmokeTests {
  /// The hosted test process has the app as its main bundle; fall back to scanning all bundles.
  static func loadLibrary() throws -> ContentLibrary {
    for bundle in [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks {
      if let lib = try? ContentLibrary.live(bundle: bundle), !lib.packs.isEmpty { return lib }
    }
    throw CocoaError(.fileNoSuchFile)
  }

  @Test func packDecodesWithSeventyRegistryItems() throws {
    let library = try Self.loadLibrary()
    let topic = try #require(library.topic("design-patterns"))
    #expect(topic.items.count == 70)
    #expect(Set(topic.items.map(\.id)).count == 70)
    #expect(library.search("strategy").first?.title == "Strategy")
  }

  @Test func pathContainsEveryItemOnce() throws {
    let library = try Self.loadLibrary()
    let topic = try #require(library.topic("design-patterns"))
    let path = try #require(library.learningPath("design-patterns"))
    #expect(path.allItems.count == topic.items.count)
    #expect(Set(path.allItems) == Set(topic.items.map(\.id)))
  }

  @Test func strategyHasAllTemplateRolesAndExercises() throws {
    let library = try Self.loadLibrary()
    let key = ItemKey(topic: "design-patterns", item: "strategy")
    let item = try #require(library.item(key))
    let template = try #require(item.template)
    #expect(item.item.cards.map(\.role) == template.roles)
    let kinds = Set(item.item.exercises.map(\.kind))
    #expect(kinds.isSuperset(of: [.identify, .choose, .recall]))
    #expect(kinds.contains(.tapLine) || kinds.contains(.reorder))
    let code = item.item.cards.compactMap { card -> CodeCard? in
      if case .code(let c) = card.content { return c } else { return nil }
    }.first
    #expect(code?.source.isEmpty == false)
  }

  @Test func everyRegistryItemHasContent() throws {
    let library = try Self.loadLibrary()
    let keys = Set(library.allItemKeys())
    let registry = try #require(library.topic("design-patterns")).items
    #expect(registry.count == 70)
    for meta in registry {
      #expect(keys.contains(ItemKey(topic: "design-patterns", item: meta.id)), "\(meta.id)")
    }
  }

  @MainActor
  @Test func practiceStartsWithStudiedItemsOnly() throws {
    let model = AppModel.make(
      container: AppModel.inMemoryContainer(),
      settings: AppSettings(defaults: UserDefaults(suiteName: "kata.tests.smoke")!))
    #expect(model.libraryError == nil)
    #expect(model.hasContent(ItemKey(topic: "design-patterns", item: "strategy")))
    #expect(model.hasContent(ItemKey(topic: "design-patterns", item: "observer")))
    // Nothing studied yet: no reviews and no new candidates.
    #expect(model.reviewQueue().isEmpty)
    // Studying Strategy makes its exercises new candidates for review.
    model.store.markStudied(ItemKey(topic: "design-patterns", item: "strategy"))
    let queue = model.reviewQueue()
    #expect(!queue.isEmpty)
    #expect(queue.allSatisfy { $0.item.item == "strategy" })
  }
}
