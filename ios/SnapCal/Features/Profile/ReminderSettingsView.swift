import SwiftUI

/// 用餐提醒设置: 开关 + 每日提醒时间
struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = ReminderManager.shared.isEnabled
    @State private var times: [(Int, Int)] = ReminderManager.shared.times
    @State private var loaded = false

    private let labels = ["早餐提醒", "午餐提醒", "晚餐提醒"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text("⏰").font(.title3)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.weakFill))
                        Text("每日用餐提醒").font(.subheadline)
                        Spacer()
                        Toggle("", isOn: $enabled)
                            .labelsHidden()
                            .tint(.brandGreen)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .cardStyle()

                if enabled {
                    VStack(spacing: 0) {
                        ForEach(times.indices, id: \.self) { i in
                            HStack {
                                Text(labels[min(i, labels.count - 1)]).font(.subheadline)
                                Spacer()
                                DatePicker("", selection: timeBinding(i), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            if i != times.count - 1 {
                                Divider().overlay(Color.dividerLine)
                            }
                        }
                    }
                    .cardStyle()

                    Text("到点会提醒你拍照或手动记录餐食")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(16)
            .background(Color.pageBG)
            .navigationTitle("用餐提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        ReminderManager.shared.times = times
                        ReminderManager.shared.isEnabled = enabled
                        dismiss()
                    }
                }
            }
            .onChange(of: enabled) { _, newValue in
                guard loaded else { return }
                ReminderManager.shared.isEnabled = newValue
            }
            .onAppear { loaded = true }
        }
    }

    private func timeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: times[index].0,
                                       minute: times[index].1, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                times[index] = (comps.hour ?? 0, comps.minute ?? 0)
            }
        )
    }
}
