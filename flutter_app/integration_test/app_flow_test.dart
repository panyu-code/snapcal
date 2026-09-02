import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:snapcal/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SnapCal complete user flow', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 首次引导三页
    if (find.text('拍一下').evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // 开发模式登录
    expect(find.text('开发模式登录 (调试)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dev-login-entry')));
    await tester.pumpAndSettle();
    final username = find.byType(TextField).first;
    await tester.enterText(username, 'fluttertest');
    await tester.tap(find.text('登录').last);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text('今日概览'), findsOneWidget);

    // 饮水卡快捷 +200
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('今日饮水'), findsOneWidget);
    await tester.tap(find.byKey(const Key('water-200')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('/ 2000 ml'), findsOneWidget);

    // 手动记录：搜索米饭 → 默认100g=116kcal → 保存
    await tester.tap(find.byKey(const Key('add-meal')));
    await tester.pumpAndSettle();
    expect(find.text('手动记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-food-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-search-field')), '米饭');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('米饭'), findsWidgets);
    final riceRow = find.byKey(const Key('food-row-1'));
    expect(riceRow, findsOneWidget);
    await tester.tap(riceRow);
    await tester.pumpAndSettle();
    // 连续添加模式选中后保持搜索页, 关闭后回到手动记录确认合计
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('合计 116 kcal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-meal')));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.textContaining('已记 '), findsWidgets);

    // 记录页 → 米饭详情 → 编辑入口
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('饮食记录'), findsOneWidget);
    expect(find.textContaining('米饭'), findsWidgets);
    await tester.tap(find.textContaining('米饭').first);
    await tester.pumpAndSettle();
    expect(find.text('餐次详情'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 我的 → 提醒设置
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('用餐提醒'), findsOneWidget);
    await tester.tap(find.text('用餐提醒'));
    await tester.pumpAndSettle();
    expect(find.text('每日用餐提醒'), findsOneWidget);
  });
}
