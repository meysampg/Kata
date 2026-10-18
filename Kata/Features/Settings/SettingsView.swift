import KataCore
import KataUI
import SwiftUI
import UserNotifications

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

  var body: some View {
    @Bindable var settings = settings
    NavigationStack {
      Form {
        reminderSection(settings: settings)
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
          HoldToConfirmButton("Hold to reset all progress") {
            model.store.resetAllProgress()
            Task { await model.refreshReminders() }
          }
        } header: {
          Text("Progress")
        } footer: {
          Text("Deletes reviews, streak, bookmarks and notes on this device. Content is not affected.")
        }
        Section {
          NavigationLink("About Kata") { AboutView() }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .task { notificationStatus = await model.reminders.authorizationStatus() }
      .onChange(of: settings.remindersEnabled) { _, on in
        Task {
          if on {
            let granted = await model.reminders.requestAuthorization()
            notificationStatus = await model.reminders.authorizationStatus()
            if !granted { settings.remindersEnabled = false }
          }
          await model.refreshReminders()
        }
      }
      .onChange(of: settings.reminderHour) { _, _ in Task { await model.refreshReminders() } }
      .onChange(of: settings.reminderMinute) { _, _ in Task { await model.refreshReminders() } }
      .onChange(of: settings.newExercisesPerDay) { _, _ in Task { await model.refreshReminders() } }
      .onChange(of: settings.dailyReviewLimit) { _, _ in Task { await model.refreshReminders() } }
    }
  }

  @ViewBuilder
  private func reminderSection(settings: AppSettings) -> some View {
    @Bindable var settings = settings
    Section {
      Toggle("Daily reminder", isOn: $settings.remindersEnabled)
      if settings.remindersEnabled {
        DatePicker("Time", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
      }
    } header: {
      Text("Reminder")
    } footer: {
      if notificationStatus == .denied {
        Text("Notifications are turned off for Kata. Enable them in the Settings app to get reminders.")
      } else {
        Text("A quiet nudge at this time on days when reviews are due.")
      }
    }
  }
}
