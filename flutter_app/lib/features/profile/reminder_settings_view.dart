import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/reminder_manager.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

/// 用餐提醒设置：保存到 Prefs，并让 ReminderManager 重排本地通知。
class ReminderSettingsView extends StatefulWidget {
  const ReminderSettingsView({super.key});

  @override
  State<ReminderSettingsView> createState() => _ReminderSettingsViewState();
}

class _ReminderSettingsViewState extends State<ReminderSettingsView> {
  static const _labels = ['早餐提醒', '午餐提醒', '晚餐提醒'];
  static const _defaults = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
  ];

  late bool _enabled;
  late List<TimeOfDay> _times;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = Prefs.reminderEnabled;
    final parsed = ReminderManager.parseTimes(Prefs.reminderTimes)
        .map((time) => TimeOfDay(hour: time.$1, minute: time.$2))
        .take(3)
        .toList();
    _times = List<TimeOfDay>.generate(
      3,
      (index) => index < parsed.length ? parsed[index] : _defaults[index],
    );
  }

  String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[index],
      helpText: _labels[index],
    );
    if (selected != null && mounted) {
      setState(() => _times[index] = selected);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final serializedTimes = _times.map(_format).join(',');
    try {
      final preferences = SharedPreferencesAsync();
      if (_enabled && !await ReminderManager.instance.requestPermission()) {
        Prefs.reminderEnabled = false;
        await preferences.setBool('snapcal-reminder-enabled', false);
        await ReminderManager.instance.apply(false);
        if (!mounted) return;
        setState(() {
          _enabled = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请先在系统设置中允许通知权限')));
        return;
      }

      Prefs.reminderTimes = serializedTimes;
      Prefs.reminderEnabled = _enabled;
      // ReminderManager 使用 SharedPreferencesAsync 读取，先等待同一组键落盘，
      // 避免首次保存后立即排程时仍读到旧时间。
      await preferences.setString('snapcal-reminder-times', serializedTimes);
      await preferences.setBool('snapcal-reminder-enabled', _enabled);
      await ReminderManager.instance.apply(_enabled);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('提醒设置失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用餐提醒'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('完成'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: const Text('⏰', style: TextStyle(fontSize: 22)),
              title: const Text('每日用餐提醒'),
              value: _enabled,
              activeTrackColor: AppColors.brandGreen,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(3, (index) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text(_labels[index]),
                        trailing: Text(
                          _format(_times[index]),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        onTap: () => _pickTime(index),
                      ),
                      if (index < 2) const Divider(height: 1),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '到点会提醒你拍照或手动记录餐食。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}
