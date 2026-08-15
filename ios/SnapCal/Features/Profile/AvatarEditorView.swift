import SwiftUI

/// 头像编辑页: 方形裁剪预览 + 缩放 + 保存/取消
struct AvatarEditorView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 圆形预览
                ZStack {
                    Circle()
                        .strokeBorder(Color.brandGreen, lineWidth: 3)
                        .background(Circle().fill(Color.cardBG))
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(Circle())
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, 1.0), 4.0)
                                }
                                .onEnded { _ in lastScale = scale }
                        )
                        .animation(.spring(duration: 0.3), value: scale)
                }
                .frame(width: 220, height: 220)
                .padding(.top, 10)

                Text("双指缩放调整头像")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 缩放滑块
                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                    Slider(value: $scale, in: 1.0...4.0, step: 0.05)
                        .onChange(of: scale) { _, newValue in lastScale = newValue }
                    Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)

                Spacer()

                // 保存按钮
                Button {
                    saving = true
                    let rendered = renderCropped()
                    onSave(rendered)
                    dismiss()
                } label: {
                    if saving { ProgressView().tint(.black) }
                    else { Text("保存头像").font(.headline) }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.brandGreen)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
            }
            .background(Color.pageBG)
            .navigationTitle("编辑头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// 按当前缩放渲染 512x512 裁剪图
    private func renderCropped() -> UIImage {
        let side = min(image.size.width, image.size.height)
        let cropRect = CGRect(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2,
            width: side, height: side
        )
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        let size = CGSize(width: 512, height: 512)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        cropped.draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? cropped
    }
}
