import SwiftUI

/// 资料编辑 + 目标设置 (调 PUT /user/profile, 后端按 Mifflin-St Jeor 算热量目标)
struct ProfileEditView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var gender = 1
    @State private var birthYear = 1998
    @State private var heightCm: Double = 172
    @State private var currentWeight: Double = 65
    @State private var goalWeight: Double = 60
    @State private var targetType = "LOSE"
    @State private var pace = "MID"
    @State private var activity = 1.2
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础资料") {
                    TextField("昵称", text: $nickname)
                    Picker("性别", selection: $gender) {
                        Text("男").tag(1); Text("女").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Picker("出生年份", selection: $birthYear) {
                        ForEach(1940...2012, id: \.self) { Text("\($0)年").tag($0) }
                    }
                    HStack {
                        Text("身高")
                        Spacer()
                        Text("\(Int(heightCm)) cm").foregroundStyle(.secondary)
                    }
                    Slider(value: $heightCm, in: 120...220, step: 1)
                    HStack {
                        Text("当前体重")
                        Spacer()
                        Text(String(format: "%.1f kg", currentWeight)).foregroundStyle(.secondary)
                    }
                    Slider(value: $currentWeight, in: 30...200, step: 0.1)
                }

                Section("目标") {
                    Picker("类型", selection: $targetType) {
                        Text("减脂").tag("LOSE")
                        Text("维持").tag("KEEP")
                        Text("增肌").tag("GAIN")
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("目标体重")
                        Spacer()
                        Text(String(format: "%.1f kg", goalWeight)).foregroundStyle(.secondary)
                    }
                    Slider(value: $goalWeight, in: 30...200, step: 0.1)
                    Picker("速度", selection: $pace) {
                        Text("慢 (-250)").tag("SLOW")
                        Text("中 (-500)").tag("MID")
                        Text("快 (-750)").tag("FAST")
                    }
                    .pickerStyle(.segmented)
                    Picker("活动量", selection: $activity) {
                        Text("久坐 (1.2)").tag(1.2)
                        Text("轻度 (1.375)").tag(1.375)
                        Text("中度 (1.55)").tag(1.55)
                        Text("高强度 (1.725)").tag(1.725)
                    }
                }

                if let errorText {
                    Section { Text(errorText).font(.caption).foregroundStyle(.brandRed) }
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() }
                    else { Button("保存") { Task { await save() } }.bold() }
                }
            }
            .onAppear { loadCurrent() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadCurrent() {
        guard let u = app.user else { return }
        nickname = u.nickname ?? ""
        gender = u.gender ?? 1
        birthYear = u.birthYear ?? 1998
        heightCm = u.heightCm ?? 172
        currentWeight = u.currentWeightKg ?? 65
        goalWeight = u.goalWeightKg ?? 60
        targetType = u.targetType ?? "LOSE"
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let req = ProfileUpdateReq(
            nickname: nickname.isEmpty ? nil : nickname,
            gender: gender,
            birthYear: birthYear,
            heightCm: heightCm,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            targetType: targetType,
            pace: pace,
            activityFactor: activity
        )
        do {
            let _: User = try await APIClient.shared.put(path: "/user/profile", body: req)
            await app.refreshMe()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
