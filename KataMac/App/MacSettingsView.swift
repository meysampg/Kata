import KataStore
import KataUI
import SwiftUI

/// The Settings window (⌘,): General, Editor, Java and IDE.
struct MacSettingsView: View {
  var body: some View {
    TabView {
      GeneralSettingsView()
        .tabItem { Label("General", systemImage: "gearshape") }
      EditorSettingsView()
        .tabItem { Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right") }
      JavaSettingsView()
        .tabItem { Label("Java", systemImage: "cup.and.saucer") }
      IDESettingsView()
        .tabItem { Label("IDE", systemImage: "macwindow") }
    }
    .frame(width: 540)
  }
}

private struct GeneralSettingsView: View {
  @Environment(MacAppModel.self) private var model
  @Environment(AppSettings.self) private var settings
  @State private var confirmReset = false

  private var version: String {
    let info = Bundle.main.infoDictionary
    let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let b = info?["CFBundleVersion"] as? String ?? "1"
    return "\(v) (\(b))"
  }

  var body: some View {
    @Bindable var settings = settings
    @Bindable var mac = model.macSettings
    Form {
      Section {
        Picker("Desired retention", selection: $settings.desiredRetention) {
          ForEach(AppSettings.retentionOptions, id: \.self) { Text("\(Int($0 * 100))%").tag($0) }
        }
        .pickerStyle(.segmented)
        Stepper(value: $settings.newExercisesPerDay, in: AppSettings.newPerDayRange) {
          LabeledContent("New exercises per day", value: "\(settings.newExercisesPerDay)")
        }
        Stepper(value: $settings.dailyReviewLimit, in: AppSettings.reviewLimitRange, step: 10) {
          LabeledContent("Review limit", value: "\(settings.dailyReviewLimit)")
        }
        Stepper(value: $mac.katasPerDay, in: MacSettings.katasPerDayRange) {
          LabeledContent("Katas per day", value: "\(mac.katasPerDay)")
        }
      } header: {
        Text("Reviews")
      } footer: {
        Text("Higher retention means more frequent reviews.")
      }

      Section("Code") {
        Slider(value: $settings.codeFontSize, in: AppSettings.codeFontRange, step: 1) {
          Text("Font size")
        } minimumValueLabel: {
          Text("12").font(.footnote)
        } maximumValueLabel: {
          Text("18").font(.footnote)
        }
        Toggle("Line numbers", isOn: $settings.showLineNumbers)
        CodeView(
          source: "interface DiscountPolicy {\n    Money apply(Money subtotal);\n}",
          fontSize: settings.codeFontPoints, showLineNumbers: settings.showLineNumbers)
          .padding(.vertical, 4)
          .accessibilityLabel("Code preview")
      }

      Section {
        Button("Reset all progress…", role: .destructive) { confirmReset = true }
          .confirmationDialog(
            "Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible
          ) {
            Button("Reset", role: .destructive) { model.store.resetAllProgress() }
            Button("Cancel", role: .cancel) {}
          } message: {
            Text("Deletes reviews, streak, bookmarks, notes and kata attempts on this Mac. Content is not affected.")
          }
      } header: {
        Text("Progress")
      } footer: {
        Text("Progress on this Mac is separate from the iPhone app.")
      }

      Section("About") {
        LabeledContent("Version", value: version)
        Link(destination: URL(string: "https://github.com/meysampg/Kata")!) {
          Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        LabeledContent("License", value: "MIT")
        Text("Kata collects nothing. Your progress stays on this Mac. There is no account, no analytics and no network access.")
          .font(.callout).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}
