# SnapCal Flutter

SnapCal 的 Flutter 双端重构版：拍一下餐盘，AI 识别食物和热量；也支持手动记录、饮水、收藏、趋势和提醒。

## 已实现功能

- 首次启动三页引导
- Apple 登录 / 开发模式登录
- 今日概览：热量圆环、三大营养素、餐次、饮水进度、健康消耗
- 拍照或相册识别：GLM-5.3-flash 视觉识别、扫描动画、份量调整、删除/替换食物
- 手动记录：餐次类型、食物搜索、收藏/常吃快捷添加、实时营养重算、备注
- 食物搜索：300ms 防抖、关键词高亮、收藏星标、连续添加
- 记录：最近 7 天分组、详情、备注、餐次/份量编辑、删除
- 食物库：分类筛选、实时搜索、分页和营养参数
- 趋势：周/月摄入图表、目标线、体重折线和记体重
- 我的：头像裁剪上传、资料编辑、浅色/深色/跟随系统
- 用餐提醒：早/午/晚本地每日通知
- 离线缓存：用户资料、今日和历史餐次
- HealthKit / Health Connect：步数和活动消耗（权限拒绝时安全降级）

## 技术栈

- Flutter 3.47.2 / Dart 3.13.2
- Provider、Dio、flutter_secure_storage、shared_preferences
- image_picker、image_cropper、fl_chart
- flutter_local_notifications、health、sign_in_with_apple
- 后端入口：`http://myblog.wiki/snapcal/api`

## 开发环境

SDK 安装在本机 `/Volumes/MacInfo` 数据盘：

```bash
export PATH="/Volumes/MacInfo/flutter/bin:$PATH"
export ANDROID_HOME=/Volumes/MacInfo/android-sdk
export JAVA_HOME="$HOME/Library/Java/JavaVirtualMachines/corretto-17.0.20/Contents/Home"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 运行与测试

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

集成测试会连接线上后端，覆盖引导、开发登录、饮水、手动餐次、食物搜索、记录详情和提醒设置：

```bash
flutter test integration_test/app_flow_test.dart -d <device-id>
```

已验证：

- Android Pixel_8 模拟器：集成测试通过
- iOS iPhone 17 模拟器：Flutter debug 包构建、启动通过
- `flutter analyze`：No issues found
- `flutter test`：全部通过

## 打包

### Android

本地 keystore 不提交 Git，构建正式 APK：

```bash
flutter build apk --release
```

交付包：`dist/SnapCal-1.0.0-android-release.apk`

### iOS

生成模拟器包：

```bash
flutter build ios --simulator --debug
```

真机安装：用 Xcode 打开 `ios/Runner.xcworkspace`，选择 iPhone 后 Run。免费 Apple ID 签名仍受 7 天有效期限制。

## 目录

```text
lib/
├── core/       API、模型、缓存、主题、健康、提醒、emoji
├── state/      AppModel、ThemeModel
└── features/   引导、登录、今日、识别、手动、搜索、记录、趋势、食物库、我的

test/             单元测试和高亮组件测试
integration_test/ Android/iOS 端到端流程测试
```
