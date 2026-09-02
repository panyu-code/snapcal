import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/app_model.dart';

enum _AuthMode { login, register, reset }

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _submitting = false;
  bool _sendingCode = false;
  bool _obscurePassword = true;
  int _codeCountdown = 0;
  Timer? _countdownTimer;
  String? _error;
  String? _notice;

  AppModel get app => context.read<AppModel>();

  @override
  void initState() {
    super.initState();
    _accountController.text = context.read<AppModel>().loginAccount;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _accountController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode || _submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _formKey.currentState?.reset();
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _codeController.clear();
    });
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '请输入$label';
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _required(value, '邮箱');
    if (requiredError != null) return requiredError;
    final email = value!.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = _required(value, _mode == _AuthMode.reset ? '新密码' : '密码');
    if (requiredError != null) return requiredError;
    if (value!.length < 6) return '密码至少需要 6 位';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return '请再次输入密码';
    if (value != _passwordController.text) return '两次输入的密码不一致';
    return null;
  }

  Future<void> _sendCode() async {
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() {
        _error = emailError;
        _notice = null;
      });
      return;
    }

    setState(() {
      _sendingCode = true;
      _error = null;
      _notice = null;
    });
    try {
      await ApiClient.instance.sendEmailCode(
        _emailController.text.trim(),
        purpose: _mode == _AuthMode.register ? 'REGISTER' : 'RESET_PASSWORD',
      );
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _codeCountdown = 60;
        _notice = '验证码已发送，请检查邮箱';
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_codeCountdown <= 1) {
          timer.cancel();
          setState(() => _codeCountdown = 0);
        } else {
          setState(() => _codeCountdown--);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _error = '验证码发送失败，请稍后重试';
      });
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.login:
          await app.login(
            _accountController.text.trim(),
            _passwordController.text,
          );
          break;
        case _AuthMode.register:
          await app.register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            code: _codeController.text.trim(),
          );
          break;
        case _AuthMode.reset:
          await ApiClient.instance.resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
          if (!mounted) return;
          _accountController.text = _emailController.text.trim();
          _formKey.currentState?.reset();
          setState(() {
            _mode = _AuthMode.login;
            _passwordController.clear();
            _confirmPasswordController.clear();
            _codeController.clear();
            _notice = '密码已重置，请使用新密码登录';
          });
          break;
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '$_submitLabel失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _title => switch (_mode) {
        _AuthMode.login => '欢迎回来',
        _AuthMode.register => '创建账号',
        _AuthMode.reset => '找回密码',
      };

  String get _subtitle => switch (_mode) {
        _AuthMode.login => '登录后继续记录你的健康生活',
        _AuthMode.register => '注册 SnapCal，开始轻松管理饮食',
        _AuthMode.reset => '验证邮箱后设置一个新密码',
      };

  String get _submitLabel => switch (_mode) {
        _AuthMode.login => '登录',
        _AuthMode.register => '注册',
        _AuthMode.reset => '重置密码',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const Text('📸', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  Text(
                    'SnapCal',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ModeSelector(mode: _mode, onChanged: _setMode),
                        const SizedBox(height: 24),
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                        const SizedBox(height: 22),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._fields(),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                _StatusMessage(text: _error!, isError: true),
                              ],
                              if (_notice != null) ...[
                                const SizedBox(height: 12),
                                _StatusMessage(text: _notice!),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.brandGreen,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: _submitting
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          _submitLabel,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ),
                              if (_mode == _AuthMode.login)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _setMode(_AuthMode.reset),
                                    child: const Text('忘记密码？'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_mode) {
      case _AuthMode.login:
        return [
          TextFormField(
            controller: _accountController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '登录账号',
              hintText: '用户名或邮箱',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => _required(value, '用户名或邮箱'),
          ),
          const SizedBox(height: 14),
          _passwordField(label: '密码', action: TextInputAction.done),
        ];
      case _AuthMode.register:
        return [
          TextFormField(
            controller: _usernameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            ],
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              final requiredError = _required(value, '用户名');
              if (requiredError != null) return requiredError;
              if (value!.trim().length < 2) return '用户名至少需要 2 位';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _emailField(),
          const SizedBox(height: 14),
          _passwordField(label: '密码'),
          const SizedBox(height: 14),
          _confirmPasswordField(),
          const SizedBox(height: 14),
          _codeField(),
        ];
      case _AuthMode.reset:
        return [
          _emailField(autofocus: true),
          const SizedBox(height: 14),
          _codeField(),
          const SizedBox(height: 14),
          _passwordField(label: '新密码'),
          const SizedBox(height: 14),
          _confirmPasswordField(),
        ];
    }
  }

  Widget _emailField({bool autofocus = false}) => TextFormField(
        controller: _emailController,
        autofocus: autofocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: '邮箱',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: _validateEmail,
      );

  Widget _passwordField({required String label, TextInputAction action = TextInputAction.next}) => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        textInputAction: action,
        autofillHints: [_mode == _AuthMode.login ? AutofillHints.password : AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
        validator: _validatePassword,
        onFieldSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
      );

  Widget _confirmPasswordField() => TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        decoration: const InputDecoration(
          labelText: '确认密码',
          prefixIcon: Icon(Icons.lock_reset_outlined),
        ),
        validator: _validateConfirmPassword,
      );

  Widget _codeField() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
              validator: (value) => _required(value, '验证码'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _sendingCode || _codeCountdown > 0 ? null : _sendCode,
              child: _sendingCode
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeCountdown > 0 ? '${_codeCountdown}s' : '发送验证码'),
            ),
          ),
        ],
      );
}

class _ModeSelector extends StatelessWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _AuthMode.values.map((item) {
          final selected = item == mode;
          final label = switch (item) {
            _AuthMode.login => '登录',
            _AuthMode.register => '注册',
            _AuthMode.reset => '找回密码',
          };
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Theme.of(context).colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String text;
  final bool isError;

  const _StatusMessage({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Theme.of(context).colorScheme.error : AppColors.brandGreenDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
