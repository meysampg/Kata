import SwiftUI

struct AboutView: View {
  private var version: String {
    let info = Bundle.main.infoDictionary
    let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let b = info?["CFBundleVersion"] as? String ?? "1"
    return "\(v) (\(b))"
  }

  var body: some View {
    Form {
      Section {
        VStack(spacing: 6) {
          Text("Kata").font(.largeTitle.weight(.semibold))
          Text("Master design patterns, one at a time.")
            .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
      }
      Section {
        LabeledContent("Version", value: version)
        Link(destination: URL(string: "https://github.com/meysampg/Kata")!) {
          Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        LabeledContent("License", value: "MIT")
      }
      Section("Privacy") {
        Text("Kata collects nothing. Your progress, bookmarks and notes stay on this device. There is no account, no analytics and no network access.")
          .font(.callout)
      }
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }
}
