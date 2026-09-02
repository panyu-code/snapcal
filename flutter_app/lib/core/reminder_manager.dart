import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 用餐提醒: 每日固定时间本地通知
class ReminderManager {
  ReminderManager._();
  static final instance = ReminderManager._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static List<(int, int)> parseTimes(String raw) => raw.split(',').map((p) {
    final parts = p.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    return h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59 ? (h, m) : null;
  }).whereType<(int, int)>().toList();

  Future<void> _init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ));
    _inited = true;
  }

  Future<bool> requestPermission() async {
    await _init();
    final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: true) ?? true;
    final android = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;
    return ios && android;
  }

  Future<void> apply(bool enabled) async {
    await _init();
    final prefs = await SharedPreferences.getInstance();
    if (!enabled) {
      await _plugin.cancelAll();
      await prefs.setBool('snapcal-reminder-enabled', false);
      return;
    }
    if (!await requestPermission()) return;
    await _plugin.cancelAll();
    final times = parseTimes(prefs.getString('snapcal-reminder-times') ?? '8:00,12:00,18:00');
    for (var i = 0; i < times.length && i < 5; i++) {
      final (hour, minute) = times[i];
      await _plugin.zonedSchedule(
        i + 1,
        '该记一餐啦 📸',
        '拍下餐盘或手动记录, 今天也吃得明白 ~',
        _nextDaily(hour, minute),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          android: AndroidNotificationDetails('meal-reminder', '用餐提醒', channelDescription: '每日固定时间提醒记录餐食', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal',
      );
    }
    await prefs.setBool('snapcal-reminder-enabled', true);
  }

  tz.TZDateTime _nextDaily(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var value = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
    return value;
  }
}
