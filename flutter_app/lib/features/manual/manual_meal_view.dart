import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/food_emoji.dart';
import '../../core/models.dart';
import '../../core/theme.dart' show AppColors;
import '../search/food_search_sheet.dart';

/// 手动记录餐次 (对齐 iOS ManualMealView)
class ManualMealView extends StatefulWidget {
  final String initialType;

  const ManualMealView({super.key, required this.initialType});

  @override
  State<ManualMealView> createState() => _ManualMealViewState();
}

class _DraftFood {
  final Food food;
  final TextEditingController controller;

  _DraftFood(this.food, {String weightText = '100'}) : controller = TextEditingController(text: weightText);

  int get weightG => int.tryParse(controller.text) ?? 0;
  int get kcal => ((food.kcalPer100g ?? 0) * weightG / 100).round();
  int get proteinG => ((food.proteinPer100g ?? 0) * weightG / 100).round();
  int get carbsG => ((food.carbsPer100g ?? 0) * weightG / 100).round();
  int get fatG => ((food.fatPer100g ?? 0) * weightG / 100).round();
}

class _ManualMealViewState extends State<ManualMealView> {
  late String _mealType = widget.initialType;
  final List<_DraftFood> _items = [];
  final _noteController = TextEditingController();
  List<Food> _favorites = [], _recents = [];
  bool _saving = false;

  int get _totalKcal => _items.fold(0, (s, i) => s + i.kcal);

  Future<void> _loadQuickPicks() async {
    try {
      final favs = await ApiClient.instance.favorites();
      final rec = await ApiClient.instance.recentFoods();
      if (mounted) setState(() { _favorites = favs; _recents = rec; });
    } catch (_) {}
  }

  void _addFood(Food food) {
    if (_items.any((i) => i.food.id == food.id)) return;
    HapticFeedback.lightImpact();
    setState(() => _items.add(_DraftFood(food)));
  }

  Future<void> _save() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final req = MealSaveReq(
        mealType: _mealType,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        items: _items.map((i) => MealSaveItem(
          foodName: i.food.name, weightG: i.weightG, kcal: i.kcal,
          proteinG: i.proteinG.toDouble(), carbsG: i.carbsG.toDouble(), fatG: i.fatG.toDouble(),
          source: 'MANUAL',
        )).toList(),
      );
      await ApiClient.instance.saveMeal(req);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadQuickPicks();
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动记录'),
        actions: [
          TextButton(
            key: const Key('save-meal'),
            onPressed: _items.isEmpty || _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // 餐次类型
        Row(spacing: 8, children: [
          for (final (type, emoji, name) in Meal.slots)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _mealType = type),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _mealType == type ? AppColors.brandGreen.withAlpha(46) : Theme.of(context).dividerColor,
                    border: Border.all(color: _mealType == type ? AppColors.brandGreen : Colors.transparent),
                  ),
                  child: Column(children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _mealType == type ? AppColors.brandGreen : null)),
                  ]),
                ),
              ),
            ),
        ]),
        // 收藏 / 常吃
        if (_favorites.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('⭐ 收藏', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in _favorites) _quickChip(f, 'fav-chip-${f.id}'),
            ]),
          ),
        ],
        if (_recents.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('🕘 常吃', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in _recents.where((r) => !_items.any((i) => i.food.id == r.id) && !_favorites.any((x) => x.id == r.id)))
                _quickChip(f, 'recent-chip-${f.id}'),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        // 食物明细
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('食物明细', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  key: const Key('open-food-search'),
                  onPressed: () => showFoodSearchSheet(context, stayOpen: true, onSelect: _addFood),
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text('添加食物', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: Text('点「添加食物」从 622 种食物库选择', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
                )
              else ...[
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Text(item.food.emoji ?? FoodEmoji.forFood(item.food.name), style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${item.kcal} kcal · 蛋白${item.proteinG}g 碳水${item.carbsG}g 脂肪${item.fatG}g', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                      ])),
                      SizedBox(
                        width: 52,
                        child: TextField(
                          key: Key('weight-${item.food.id}'),
                          controller: item.controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 6)),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const Text('g', style: TextStyle(fontSize: 11)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Color(0xFFF87171)),
                        onPressed: () => setState(() => _items.remove(item)),
                      ),
                    ]),
                  ),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('合计 $_totalKcal kcal', key: const Key('total-kcal'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandGreen)),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // 备注
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('备注 (选填)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(hintText: '如: 公司食堂 / 少油'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _quickChip(Food f, String key) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        key: Key(key),
        borderRadius: BorderRadius.circular(19),
        onTap: () => _addFood(f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(19), color: Theme.of(context).dividerColor),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(f.emoji ?? FoodEmoji.forFood(f.name), style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(f.name, style: const TextStyle(fontSize: 12)),
            const Icon(Icons.add_circle, size: 14, color: AppColors.brandGreen),
          ]),
        ),
      ),
    );
  }
}
