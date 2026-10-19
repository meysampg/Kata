import SwiftData

/// V1 (cards, logs, item progress, daily activity) to V2 (adds kata attempts and solutions).
/// The stage is lightweight: V2 only adds two entities, V1 rows are untouched.
public enum KataMigrationPlan: SchemaMigrationPlan {
  public static var schemas: [any VersionedSchema.Type] { [KataSchemaV1.self, KataSchemaV2.self] }
  public static var stages: [MigrationStage] {
    [.lightweight(fromVersion: KataSchemaV1.self, toVersion: KataSchemaV2.self)]
  }
}
