import SwiftUI
import AVFoundation
import PhotosUI

/// 相机拍照视图 (AVFoundation); 模拟器无相机时回退相册选择
struct CameraCaptureView: View {
    var onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if cameraAvailable {
                    CameraPreview(onCapture: onCapture, dismiss: dismiss)
                } else {
                    // 模拟器/无相机设备: 相册回退
                    VStack(spacing: 18) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 46)).foregroundStyle(.secondary)
                        Text("当前设备没有可用相机").font(.headline)
                        Text("请从相册选择餐盘照片").font(.caption).foregroundStyle(.secondary)
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("从相册选择", systemImage: "photo.on.rectangle")
                                .font(.headline)
                                .frame(maxWidth: .infinity).frame(height: 50)
                                .background(Color.brandGreen).foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.pageBG)
                }
            }
            .navigationTitle("拍摄餐盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onCapture(image)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// AVCaptureSession 相机预览 + 拍照
private struct CameraPreview: View {
    let onCapture: (UIImage) -> Void
    let dismiss: DismissAction

    @State private var session = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var errorText: String?
    @State private var capturedImage: UIImage?
    @State private var photoDelegate: PhotoDelegate?   // 强持有, 防弱引用提前释放

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let previewLayer {
                    PreviewContainer(layer: previewLayer)
                } else {
                    Text(errorText ?? "初始化相机…")
                        .font(.caption).foregroundStyle(.white)
                }
                // 取景引导框
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.brandGreen, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(maxWidth: 300, maxHeight: 340)
                    .padding(30)
                VStack {
                    Spacer()
                    Text("对准餐盘 · AI 自动识别")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 30)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部快门
            HStack {
                Spacer()
                Button {
                    capture()
                } label: {
                    Circle().strokeBorder(.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().fill(Color.white).padding(7))
                }
                Spacer()
            }
            .padding(.vertical, 26)
            .background(Color.black)
        }
        .ignoresSafeArea(edges: .bottom)
        .task { setup() }
        .onChange(of: capturedImage) { _, image in
            if let image {
                onCapture(image)
                dismiss()
            }
        }
    }

    private func setup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { configure() } }
            }
        default:
            errorText = "未获得相机权限，请到 设置→SnapCal 开启相机"
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorText = "相机初始化失败"
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func capture() {
        let delegate = PhotoDelegate { image in
            DispatchQueue.main.async { self.capturedImage = image }
        }
        photoDelegate = delegate   // 强持有防止回调丢失
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}

private class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let handler: (UIImage?) -> Void
    init(handler: @escaping (UIImage?) -> Void) { self.handler = handler }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            handler(image)
        } else {
            handler(nil)
        }
    }
}

/// UIViewRepresentable 包装预览层 (layoutSubviews 保证 frame 正确)
private struct PreviewContainer: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        uiView.previewLayer = layer
        uiView.layoutIfNeeded()
    }
}

private final class PreviewHostView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let previewLayer {
                layer.addSublayer(previewLayer)
                setNeedsLayout()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
