import KataCore
import KataDiagram
import KataUI
import SwiftUI

struct DiagramCardView: View {
  let diagrams: [Diagram]
  @State private var index = 0
  @State private var isExpanded = false
  @State private var selectedRole: String?

  private var diagram: Diagram? { diagrams.indices.contains(index) ? diagrams[index] : nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if diagrams.count > 1 {
        Picker("Diagram", selection: $index) {
          ForEach(diagrams.indices, id: \.self) { Text(diagrams[$0].title).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: index) { _, _ in selectedRole = nil }
      }
      if let diagram {
        DiagramView(diagram: diagram) { id in selectedRole = id.flatMap { Self.role(of: $0, in: diagram) } }
          .id(index)
          .padding(10)
          .background(.background.secondary, in: .rect(cornerRadius: Theme.cardRadius))
        HStack {
          if let selectedRole {
            Label(selectedRole, systemImage: "tag").font(.subheadline.weight(.medium))
          } else {
            Text("Tap a type to see its role.").font(.footnote).foregroundStyle(.secondary)
          }
          Spacer()
          Button { isExpanded = true } label: {
            Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .controlSize(.small)
        }
      }
    }
    .sheet(isPresented: $isExpanded) {
      if let diagram {
        NavigationStack {
          ZoomableDiagramView(diagram: diagram)
            .navigationTitle(diagram.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) { Button("Done") { isExpanded = false } }
            }
        }
        .presentationDetents([.large])
      }
    }
  }

  private static func role(of id: String, in diagram: Diagram) -> String? {
    func label(_ name: String, _ role: String?) -> String { role.map { "\(name): \($0)" } ?? name }
    switch diagram {
    case .classDiagram(let d): return d.nodes.first { $0.id == id }.map { label($0.name, $0.role) }
    case .sequence(let d): return d.participants.first { $0.id == id }.map { label($0.name, $0.role) }
    }
  }
}
