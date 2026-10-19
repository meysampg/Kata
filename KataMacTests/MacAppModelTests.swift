import Foundation
import KataCore
import KataStore
import Testing

@testable import KataMac

@MainActor
struct MacAppModelTests {
  static func makeModel() -> MacAppModel {
    let defaults = UserDefaults(suiteName: "kata.mac.tests") ?? .standard
    defaults.removePersistentDomain(forName: "kata.mac.tests")
    return MacAppModel.make(
      container: MacAppModel.inMemoryContainer(), settings: AppSettings(defaults: defaults),
      macSettings: MacSettings(defaults: defaults))
  }

  static let strategy = ItemKey(topic: "design-patterns", item: "strategy")

  @Test func bundleHasPackAndKata() throws {
    let model = Self.makeModel()
    #expect(model.libraryError == nil)
    let topic = try #require(model.library.topic("design-patterns"))
    #expect(topic.items.count == 70)
    #expect(model.library.kata(Self.strategy) != nil)
    #expect(model.study.kataKeys.contains(Self.strategy))
  }

  @Test func storeLivesInTheAppsOwnFolder() {
    let url = MacAppModel.storeURL()
    #expect(url.path.hasSuffix("com.github.meysampg.kata.mac/Kata.store"))
    #expect(!url.path.hasSuffix("default.store"))
  }

  @Test func selectionChangeClearsThePathAndOpenPushes() {
    let model = Self.makeModel()
    model.show(.library)
    model.open(Self.strategy)
    #expect(model.path.count == 1)
    model.show(.path)
    #expect(model.path.count == 0)
  }

  @Test func kataIsOfferedOnlyAfterTheItemIsStudied() {
    let model = Self.makeModel()
    #expect(model.dueKatas().isEmpty)
    model.store.markStudied(Self.strategy)
    #expect(model.dueKatas() == [Self.strategy])
  }

  @Test func linksResolveRelativeToTheTopic() {
    let model = Self.makeModel()
    let key = model.resolve(link: URL(string: "kata:strategy")!, in: "design-patterns")
    #expect(key == Self.strategy)
  }
}
