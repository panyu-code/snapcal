import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token 存取 (iOS Keychain / Android Keystore)
class TokenStore {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _key = 'snapcal-auth-token';

  static Future<String?> read() async => _storage.read(key: _key);
  static Future<void> write(String? token) async =>
      token == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: token);
}

/// 离线缓存 (替代 iOS 版 SwiftData CacheStore, 文件 JSON 存储)
class CacheStore {
  static File? _file;

  static Future<File> _cacheFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/snapcal-cache.json');
    return _file!;
  }

  static Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _cacheFile();
      if (!f.existsSync()) return {};
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(String key, Object value) async {
    try {
      final all = await _readAll();
      all[key] = {'v': value, 't': DateTime.now().millisecondsSinceEpoch};
      final f = await _cacheFile();
      f.writeAsStringSync(jsonEncode(all));
    } catch (_) {}
  }

  static Future<T?> load<T>(String key, T Function(dynamic json) fromJson) async {
    try {
      final all = await _readAll();
      final entry = all[key];
      if (entry == null) return null;
      return fromJson((entry as Map<String, dynamic>)['v']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) async {
    try {
      final all = await _readAll();
      all.remove(key);
      final f = await _cacheFile();
      f.writeAsStringSync(jsonEncode(all));
    } catch (_) {}
  }
}

/// 轻量偏好 (SharedPreferences 封装)
class Prefs {
  static late SharedPreferences _p;

  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static bool get onboarded => _p.getBool('snapcal-onboarded') ?? false;
  static set onboarded(bool v) => _p.setBool('snapcal-onboarded', v);

  static String get loginAccount => _p.getString('snapcal-login-account') ?? '';
  static set loginAccount(String v) => _p.setString('snapcal-login-account', v);

  /// 0 system / 1 light / 2 dark
  static int get themeMode => _p.getInt('snapcal-theme') ?? 0;
  static set themeMode(int v) => _p.setInt('snapcal-theme', v);

  /// 提醒时间 "8:00,12:00,18:00"
  static String get reminderTimes => _p.getString('snapcal-reminder-times') ?? '8:00,12:00,18:00';
  static set reminderTimes(String v) => _p.setString('snapcal-reminder-times', v);

  static bool get reminderEnabled => _p.getBool('snapcal-reminder-enabled') ?? false;
  static set reminderEnabled(bool v) => _p.setBool('snapcal-reminder-enabled', v);
}
