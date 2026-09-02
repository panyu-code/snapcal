import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/storage.dart';

/// 全局状态: 登录态 + 当前用户 (对齐 iOS 版 AppModel)
class AppModel extends ChangeNotifier {
  User? user;
  bool booted = false;

  bool get isLoggedIn => user != null;
  String get loginAccount => Prefs.loginAccount;

  /// 启动恢复会话: 有缓存用户直接进主界面, 仅明确 401 才登出
  Future<void> restoreSession() async {
    booted = true;
    final token = await TokenStore.read();
    if (token == null) {
      notifyListeners();
      return;
    }
    user = await CacheStore.load('me', (j) => User.fromJson(j));
    notifyListeners();
    try {
      final fresh = await ApiClient.instance.me();
      user = fresh;
      await CacheStore.save('me', fresh.toJson());
    } on ApiException catch (e) {
      if (e.code == 401) {
        await logout();
      }
      // 其他错误 (超时/网络) 保留缓存用户
    } catch (_) {}
    notifyListeners();
  }

  Future<void> login(String account, String password) async {
    final (token, u) = await ApiClient.instance.login(account, password);
    await _saveSession(token, u);
    Prefs.loginAccount = account;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String code,
  }) async {
    final (token, u) = await ApiClient.instance.register(
      username: username,
      email: email,
      password: password,
      code: code,
    );
    await _saveSession(token, u);
    Prefs.loginAccount = username;
  }

  Future<void> _saveSession(String token, User currentUser) async {
    await TokenStore.write(token);
    user = currentUser;
    await CacheStore.save('me', currentUser.toJson());
    notifyListeners();
  }

  Future<void> logout() async {
    await TokenStore.write(null);
    user = null;
    await CacheStore.remove('me');
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    Prefs.onboarded = true;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try {
      final u = await ApiClient.instance.me();
      user = u;
      await CacheStore.save('me', u.toJson());
      notifyListeners();
    } catch (_) {}
  }
}

/// 主题状态: 0 system / 1 light / 2 dark
class ThemeModel extends ChangeNotifier {
  ThemeMode get mode => switch (Prefs.themeMode) { 1 => ThemeMode.light, 2 => ThemeMode.dark, _ => ThemeMode.system };

  String get label => switch (Prefs.themeMode) { 1 => '浅色', 2 => '深色', _ => '跟随系统' };

  void setMode(ThemeMode m) {
    Prefs.themeMode = switch (m) { ThemeMode.light => 1, ThemeMode.dark => 2, _ => 0 };
    notifyListeners();
  }
}
