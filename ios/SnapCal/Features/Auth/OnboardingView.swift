import SwiftUI

/// 首次启动引导页 (3 页滑动)
struct OnboardingView: View {
    @AppStorage("snapcal-onboarded") private var onboarded = false
    @State private var page = 0

    private let pages: [(emoji: String, title: String, desc: String)] = [
        ("📸", "拍一下，吃明白",
         "对准餐盘拍张照片，AI 自动识别食物、估算克重和热量，3 秒完成一餐记录。"),
        ("🥗", "吃得有数",
         "卡路里圆环、三大营养素进度、每日摄入趋势，减脂增肌都心里有数。"),
        ("📉", "看见变化",
         "体重曲线 + 达标天数统计，坚持记录，看见身体的变化。")
    ]

    var body: some View {
        ZStack {
            Color.pageBG.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 26) {
                        Spacer()
                        Text(item.emoji).font(.system(size: 96))
                        Text(item.title).font(.title.bold())
                        Text(item.desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 42)
                        Spacer()
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                Spacer()
                Button {
                    onboarded = true
                } label: {
                    Text(page == pages.count - 1 ? "开始使用" : "跳过")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.brandGreen)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
    }
}
