import Foundation

public struct LoadReport: Sendable {
  public var topic: Topic?
  /// Successfully loaded item bodies, in registry order.
  public var items: [Item]
  /// Registry items that have no `items/<id>/` directory.
  public var missingItems: [ItemID]
  /// Items whose directory exists but failed to load (already reported in `issues`).
  public var failedItems: [ItemID]
  public var issues: [ValidationIssue]

  public var hasErrors: Bool { issues.contains { $0.severity == .error } }
  public var pack: Pack? { topic.map { Pack(topic: $0, items: items) } }
}

public struct BuildFailure: Error, Sendable, CustomStringConvertible {
  public var issues: [ValidationIssue]
  public var description: String { issues.map(\.description).joined(separator: "\n") }
}

/// Compiles an authoring directory (`topic.json`, `items/<id>/item.json`, `*.java`) into a
/// `Pack`. Deterministic: registry order for items, sorted keys when encoded.
public enum PackBuilder {
  /// `contentRoot/topics/*` directories that contain a `topic.json`.
  public static func topicDirectories(contentRoot: URL) -> [URL] {
    let topics = contentRoot.appendingPathComponent("topics", isDirectory: true)
    let dirs = (try? FileManager.default.contentsOfDirectory(
      at: topics, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
    return dirs.filter {
      FileManager.default.fileExists(atPath: $0.appendingPathComponent("topic.json").path)
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// Loads and assembles a topic. Never throws: problems are returned as issues.
  /// - Parameter only: restricts loading to these item ids.
  public static func load(topicDirectory dir: URL, only: Set<ItemID>? = nil) -> LoadReport {
    var report = LoadReport(topic: nil, items: [], missingItems: [], failedItems: [], issues: [])
    let dirName = dir.lastPathComponent
    let topicFile = dir.appendingPathComponent("topic.json")

    let topic: Topic
    do {
      topic = try JSONDecoder().decode(Topic.self, from: Data(contentsOf: topicFile))
    } catch {
      report.issues.append(.init(.error, "\(dirName)/topic.json", describe(error)))
      return report
    }
    report.topic = topic

    let itemsDir = dir.appendingPathComponent("items", isDirectory: true)
    let fm = FileManager.default
    let onDisk = Set(
      ((try? fm.contentsOfDirectory(atPath: itemsDir.path)) ?? []).filter { name in
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: itemsDir.appendingPathComponent(name).path, isDirectory: &isDir)
          && isDir.boolValue && !name.hasPrefix(".")
      })
    let registry = Set(topic.items.map(\.id))
    for name in onDisk.subtracting(registry).sorted() {
      report.issues.append(
        .init(.error, "\(topic.id)/\(name)", "items/\(name) is not in the topic registry"))
    }

    for meta in topic.items {
      if let only, !only.contains(meta.id) { continue }
      guard onDisk.contains(meta.id) else {
        report.missingItems.append(meta.id)
        continue
      }
      let itemDir = itemsDir.appendingPathComponent(meta.id, isDirectory: true)
      let path = "\(topic.id)/\(meta.id)"
      let before = report.issues.count
      if let item = loadItem(topic: topic, itemDir: itemDir, id: meta.id, path: path, issues: &report.issues),
        report.issues.count == before || !report.issues[before...].contains(where: { $0.severity == .error })
      {
        report.items.append(item)
      } else {
        report.failedItems.append(meta.id)
      }
    }
    return report
  }

  private static func loadItem(
    topic: Topic, itemDir: URL, id: ItemID, path: String, issues: inout [ValidationIssue]
  ) -> Item? {
    let file = itemDir.appendingPathComponent("item.json")
    var item: Item
    do {
      let decoder = JSONDecoder()
      decoder.userInfo[.kataRoleTypes] = topic.roleTypes
      item = try decoder.decode(Item.self, from: Data(contentsOf: file))
    } catch {
      issues.append(.init(.error, "\(path)/item.json", describe(error)))
      return nil
    }
    if item.id != id {
      issues.append(.init(.error, "\(path)/item.json", "id '\(item.id)' does not match directory '\(id)'"))
    }
    for (i, card) in item.cards.enumerated() {
      guard case .code(var code) = card.content else { continue }
      let src = itemDir.appendingPathComponent(code.file)
      do {
        let raw = try String(contentsOf: src, encoding: .utf8)
        let stripped = try MarkerStripper.strip(raw)
        code.source = stripped.source
        code.regions = stripped.regions
        item.cards[i].content = .code(code)
      } catch let e as MarkerError {
        issues.append(.init(.error, "\(path)/\(code.file)", e.description))
      } catch {
        issues.append(.init(.error, "\(path)/\(code.file)", "cannot read file: \(error.localizedDescription)"))
      }
    }
    return item
  }

  /// Assembles the pack or throws `BuildFailure` listing every error.
  public static func build(topicDirectory: URL, only: Set<ItemID>? = nil) throws -> Pack {
    let report = load(topicDirectory: topicDirectory, only: only)
    guard !report.hasErrors, let pack = report.pack else { throw BuildFailure(issues: report.issues) }
    return pack
  }

  /// Minified JSON with sorted keys; byte-for-byte reproducible.
  public static func encode(_ pack: Pack) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(pack)
    data.append(0x0A)
    return data
  }

  static func describe(_ error: Error) -> String {
    if let e = error as? DecodingError { return DecodingErrorFormatter.describe(e) }
    return (error as NSError).localizedDescription
  }
}
