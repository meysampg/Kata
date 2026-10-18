import SwiftData

/// Only V1 exists. Add `KataSchemaV2` to `schemas` and a stage to `stages` for the next change.
enum KataMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [KataSchemaV1.self] }
  static var stages: [MigrationStage] { [] }
}
