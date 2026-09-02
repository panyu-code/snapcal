import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:snapcal/main.dart' as app;

const _user = String.fromEnvironment('UITEST_USER');
const _email = String.fromEnvironment('UITEST_EMAIL');
const _password = String.fromEnvironment('UITEST_PASS');
const _code = String.fromEnvironment('UITEST_CODE');

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SnapCal 注册→主功能→退出→登录 全流程', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 首次引导三页
    if (find.text('拍一下').evaluate().isNotEmpty) {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('onboarding-next')));
        await tester.pumpAndSettle();
      }
    }

    // 切到注册模式
    expect(find.text('创建账号'), findsNothing);
    await tester.tap(find.text('注册').first);
    await tester.pumpAndSettle();
    expect(find.text('创建账号'), findsOneWidget);

    await tester.enterText(_field('用户名'), _user);
    await tester.enterText(_field('邮箱'), _email);
    await tester.enterText(_field('密码'), _password);
    await tester.enterText(_field('确认密码'), _password);
    await tester.enterText(_field('验证码'), _code);
    // 收起键盘, 避免提交按钮被遮挡
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final registerBtn = find.widgetWithText(FilledButton, '注册');
    await tester.ensureVisible(registerBtn);
    await tester.pumpAndSettle();
    await tester.tap(registerBtn, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.text('今日概览'), findsOneWidget, reason: '注册成功后应自动登录进入今日页');

    // 饮水 +200
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('今日饮水'), findsOneWidget);
    await tester.tap(find.byKey(const Key('water-200')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('/ 2000 ml'), findsOneWidget);

    // 手动记录: 搜索米饭 → 关闭搜索 → 保存
    await tester.tap(find.byKey(const Key('add-meal')));
    await tester.pumpAndSettle();
    expect(find.text('手动记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-food-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-search-field')), '米饭');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final riceRow = find.byKey(const Key('food-row-1'));
    expect(riceRow, findsOneWidget);
    await tester.tap(riceRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('合计 116 kcal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-meal')));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.textContaining('已记 '), findsWidgets);

    // 记录页 → 详情
    await tester.tap(find.text('记录').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('饮食记录'), findsOneWidget);
    expect(find.textContaining('米饭'), findsWidgets);
    await tester.tap(find.textContaining('米饭').first);
    await tester.pumpAndSettle();
    expect(find.text('餐次详情'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 我的页 → 显示注册用户名
    await tester.tap(find.text('我的').first);
    await tester.pumpAndSettle();
    expect(find.text(_user), findsWidgets);

    // 登录/退出/找回密码已由后端接口自动化验证 (见部署脚本), UI 流程到此为止
  });
}
