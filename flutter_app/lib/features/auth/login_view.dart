import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as sia;

import '../../core/api_client.dart';
import '../../state/app_model.dart';

/// 登录页: Apple 登录 + 开发模式登录 (对齐 iOS LoginView)
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  String? _error;

  AppModel get app => context.read<AppModel>();

  Future<void> _devLogin() async {
    final controller = TextEditingController(text: app.devUsername);
    final username = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('开发模式登录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Text('直连后端创建/进入测试账号', style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
            decoration: const InputDecoration(hintText: '用户名 (字母数字)'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF34D399), foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('登录', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
    if (username == null || username.length < 2) return;
    try {
      await app.devLogin(username);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '登录失败: $e');
    }
  }

  Future<void> _appleLogin() async {
    try {
      final credential = await sia.SignInWithApple.getAppleIDCredential(
        scopes: [sia.AppleIDAuthorizationScopes.fullName],
      );
      final token = credential.identityToken;
      if (token == null) {
        setState(() => _error = 'Apple 登录失败');
        return;
      }
      final fullName = [credential.familyName, credential.givenName].whereType<String>().join();
      await app.appleLogin(token, fullName.isEmpty ? null : fullName);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      if ('$e'.contains('canceled')) return;
      setState(() => _error = 'Apple 登录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 2),
            const Text('📸', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 14),
            Text('SnapCal', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('拍一下，吃明白', style: TextStyle(color: Theme.of(context).hintColor)),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: sia.SignInWithAppleButton(
                onPressed: _appleLogin,
                style: sia.SignInWithAppleButtonStyle.black,
                height: 54,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              key: const Key('dev-login-entry'),
              onPressed: _devLogin,
              child: Text('开发模式登录 (调试)', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor, decoration: TextDecoration.underline)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
              ),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}
