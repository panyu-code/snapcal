import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/storage.dart';
import 'core/theme.dart';
import 'features/auth/login_view.dart';
import 'features/onboarding/onboarding_view.dart';
import 'features/root/root_view.dart';
import 'state/app_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  final app = AppModel();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: app),
    ChangeNotifierProvider(create: (_) => ThemeModel()),
  ], child: SnapCalApp(app: app)));
}

class SnapCalApp extends StatelessWidget {
  final AppModel app;

  const SnapCalApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeModel>();
    return MaterialApp(
      title: 'SnapCal',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: theme.mode,
      home: RootGate(app: app),
    );
  }
}

/// 启动门卫: 恢复会话后 分流 引导/登录/主框架
class RootGate extends StatelessWidget {
  final AppModel app;

  const RootGate({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.booted) {
          app.restoreSession();
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!Prefs.onboarded) return const OnboardingView();
        if (app.isLoggedIn) return const RootView();
        return const LoginView();
      },
    );
  }
}
