import Foundation
import SwiftData

/// Builds the progress `ModelContainer` with the current schema and the migration plan.
public enum PersistenceFactory {
  /// - Parameters:
  ///   - url: explicit store file. `nil` uses SwiftData's default location (what iOS has always
  ///     used, so existing data keeps opening). A non-sandboxed Mac app must pass its own URL.
  ///   - inMemory: ignores `url` and keeps nothing on disk (tests, demo mode).
  public static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KataSchemaV2.self)
    if inMemory {
      return try ModelContainer(
        for: schema, migrationPlan: KataMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    if let url {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      return try ModelContainer(
        for: schema, migrationPlan: KataMigrationPlan.self,
        configurations: ModelConfiguration(schema: schema, url: url))
    }
    return try ModelContainer(for: schema, migrationPlan: KataMigrationPlan.self)
  }
}
