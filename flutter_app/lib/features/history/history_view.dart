import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/food_emoji.dart';
import '../../core/models.dart';
import '../../core/storage.dart';
import 'meal_detail_view.dart';

/// 记录页: 最近 7 天按日分组 (对齐 iOS HistoryView)
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  Map<String, List<Meal>> _days = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    if (_days.isEmpty) {
      final cached = await CacheStore.load('meals-range-7', (j) => (j as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).map((e) => Meal.fromJson(e)).toList())));
      if (cached != null) setState(() => _days = cached);
    }
    try {
      final fresh = await ApiClient.instance.mealsRange(7);
      if (mounted) setState(() => _days = fresh);
      await CacheStore.save('meals-range-7', fresh.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())));
    } catch (_) {}
    _loading = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keys = _days.keys.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('饮食记录')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: keys.isEmpty
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: Column(children: [Icon(Icons.restaurant_menu, size: 48), SizedBox(height: 8), Text('还没有记录'), Text('点右下角相机按钮，拍下第一餐吧', style: TextStyle(fontSize: 12))])),
              ])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                for (final key in keys) ...[
                  _daySection(context, key, _days[key] ?? []),
                  const SizedBox(height: 12),
                ],
              ]),
      ),
    );
  }

  Widget _daySection(BuildContext context, String dateKey, List<Meal> meals) {
    final total = meals.fold<int>(0, (s, m) => s + (m.totalKcal ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(dayTitleZh(dateKey), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('共 $total kcal', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ]),
      ),
      for (final meal in meals) ...[
        _mealCard(context, meal),
        const SizedBox(height: 8),
      ],
    ]);
  }

  Widget _mealCard(BuildContext context, Meal meal) {
    final emoji = switch (meal.mealType) { 'BREAKFAST' => '🥣', 'LUNCH' => '🍱', 'DINNER' => '🍜', _ => '🍎' };
    final chips = (meal.items ?? []).take(4).map((i) {
      final emoji = FoodEmoji.forFood(i.foodName);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Theme.of(context).dividerColor),
        child: Text('$emoji ${i.foodName} ${i.weightG}g', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
      );
    }).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailView(meal: meal)));
        _load();
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
              Text(meal.mealTypeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (chips.isNotEmpty) Wrap(spacing: 5, runSpacing: 4, children: chips),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${meal.totalKcal ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('kcal', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
            ]),
          ]),
        ),
      ),
    );
  }
}
