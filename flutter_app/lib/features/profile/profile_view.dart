import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/health_manager.dart';
import '../../core/reminder_manager.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../state/app_model.dart';
import '../library/food_library_view.dart';
import 'profile_edit_view.dart';
import 'reminder_settings_view.dart';

/// 我的：头像、目标概览及账户设置入口。
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _picker = ImagePicker();
  bool _avatarUploading = false;

  Future<void> _chooseAvatarSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (selected == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: selected.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 78,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            lockAspectRatio: true,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      await _uploadAvatar(File(cropped.path));
    } catch (error) {
      if (mounted) _showMessage('无法选择图片：$error');
    }
  }

  Future<void> _uploadAvatar(File file) async {
    setState(() => _avatarUploading = true);
    try {
      final app = context.read<AppModel>();
      app.user = await ApiClient.instance.uploadAvatar(file);
      await app.refreshMe();
      if (mounted) {
        setState(() => _avatarUploading = false);
        _showMessage('头像已更新');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _avatarUploading = false);
      _showMessage(error is ApiException ? error.message : '头像上传失败');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit() async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const ProfileEditView()));
    if (mounted) setState(() {});
  }

  Future<void> _showThemePicker() async {
    final theme = context.read<ThemeModel>();
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ThemeMode>(
              groupValue: theme.mode,
              onChanged: (value) => Navigator.pop(context, value),
              child: const Column(
                children: [
                  RadioListTile(value: ThemeMode.system, title: Text('跟随系统')),
                  RadioListTile(value: ThemeMode.light, title: Text('浅色')),
                  RadioListTile(value: ThemeMode.dark, title: Text('深色')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) theme.setMode(selected);
  }

  Future<void> _connectHealth() async {
    await HealthManager.instance.requestAuthorization();
    if (mounted) _showMessage('健康数据授权请求已完成');
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('退出后需要重新登录才能查看记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppModel>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final user = app.user;
    final theme = context.watch<ThemeModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: app.refreshMe,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
          children: [
            AppCard(
              child: Row(
                children: [
                  _Avatar(
                    avatarUrl: user?.avatar,
                    uploading: _avatarUploading,
                    onTap: _avatarUploading ? null : _chooseAvatarSource,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname?.trim().isNotEmpty == true
                              ? user!.nickname!
                              : '未命名',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SnapCal 陪你吃得明白 · 目标 ${user?.dailyKcalTarget ?? 2200} kcal/天',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _GoalCard(onEdit: _openEdit),
            const SizedBox(height: 14),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: '👤',
                    title: '个人资料',
                    value: _profileSummary(user?.birthYear, user?.heightCm),
                    onTap: _openEdit,
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: '🎨',
                    title: '主题',
                    value: theme.label,
                    onTap: _showThemePicker,
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: '📦',
                    title: '食物库',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FoodLibraryView(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: '⏰',
                    title: '用餐提醒',
                    value: _reminderSummary(),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReminderSettingsView(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: '❤️',
                    title: '健康数据',
                    value: 'Apple 健康 / Health Connect',
                    onTap: _connectHealth,
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: '🚪',
                    title: '退出登录',
                    destructive: true,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reminderSummary() {
    if (!Prefs.reminderEnabled) return '关';
    return ReminderManager.parseTimes(Prefs.reminderTimes)
        .take(3)
        .map(
          (time) =>
              '${time.$1.toString().padLeft(2, '0')}:${time.$2.toString().padLeft(2, '0')}',
        )
        .join(' ');
  }

  static String _profileSummary(int? birthYear, double? heightCm) {
    if (birthYear == null && heightCm == null) return '待完善';
    return [
      if (heightCm != null) '${heightCm.round()}cm',
      if (birthYear != null) '$birthYear年',
    ].join(' · ');
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarUrl,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox.square(
        dimension: 68,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.brandGreen, AppColors.brandBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: url == null || url.isEmpty
                    ? const Center(
                        child: Text('🐟', style: TextStyle(fontSize: 31)),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('🐟', style: TextStyle(fontSize: 31)),
                        ),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            if (uploading)
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x77000000),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppModel>().user;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🎯 ${user?.targetTypeName ?? '减脂'}目标',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('编辑')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _GoalValue(
                value: user?.currentWeightKg?.toStringAsFixed(1) ?? '—',
                label: '当前 kg',
              ),
              _GoalValue(
                value: user?.goalWeightKg?.toStringAsFixed(1) ?? '—',
                label: '目标 kg',
              ),
              _GoalValue(
                value: '${user?.dailyKcalTarget ?? '—'}',
                label: '每日 kcal',
                color: AppColors.brandOrange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.currentWeightKg == null || user?.goalWeightKg == null
                ? '完善资料与体重后显示目标'
                : _goalHint(
                    user!.currentWeightKg!,
                    user.goalWeightKg!,
                    user.targetType,
                  ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static String _goalHint(double current, double goal, String? targetType) {
    final delta = (goal - current).abs();
    if (delta < 0.05 || targetType == 'KEEP') return '保持当前节奏，持续记录每一餐';
    return '距离目标还有 ${delta.toStringAsFixed(1)} kg';
  }
}

class _GoalValue extends StatelessWidget {
  const _GoalValue({
    required this.value,
    required this.label,
    this.color = AppColors.brandGreenDark,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value = '',
    this.destructive = false,
  });

  final String icon;
  final String title;
  final String value;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 19)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
