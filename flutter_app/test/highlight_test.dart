import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:snapcal/features/search/food_search_sheet.dart';

void main() {
  testWidgets('highlights all matching keyword spans', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HighlightedText('鸡胸肉沙拉配鸡胸', keyword: '鸡胸'))));
    final rich = tester.widget<RichText>(find.byType(RichText));
    final span = rich.text as TextSpan;
    final colored = span.children!.whereType<TextSpan>().where((s) => s.style?.color == const Color(0xFF34D399)).toList();
    expect(colored.map((s) => s.text), ['鸡胸', '鸡胸']);
  });
}
