import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/health_manager.dart';
import '../../core/models.dart';
import '../../core/storage.dart';
import '../../core/theme.dart' show AppColors;
import '../../state/app_model.dart';
import '../manual/manual_meal_view.dart';

/// 今日页: 圆环 + 营养素 + 餐次列表 + 饮水 + 消耗 (对齐 iOS TodayView)
class TodayView extends StatefulWidget {
  const TodayView({super.key});

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  List<Meal> _meals = [];
  WaterToday _water = WaterToday(date: '', totalMl: 0, goalMl: 2000);
  int _steps = 0, _activeEnergy = 0;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (_loading) return;
    _loading = true;
    final cacheKey = 'meals-${dateKey(DateTime.now())}';
    if (_meals.isEmpty) {
      final cached = await CacheStore.load(cacheKey, (j) => (j as List).map((e) => Meal.fromJson(e)).toList());
      if (cached != null) setState(() => _meals = cached);
    }
    try {
      final fresh = await ApiClient.instance.mealsOfDay();
      setState(() => _meals = fresh);
      await CacheStore.save(cacheKey, fresh.map((e) => e.toJson()).toList());
    } catch (_) {}
    try {
      final w = await ApiClient.instance.waterToday();
      setState(() => _water = w);
    } catch (_) {}
    if (!_loaded) {
      _loaded = true;
      await HealthManager.instance.requestAuthorization();
      final steps = await HealthManager.instance.todaySteps();
      final energy = await HealthManager.instance.todayActiveEnergy();
      if (mounted) setState(() { _steps = steps; _activeEnergy = energy; });
    }
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _openManual([String presetType = '']) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualMealView(initialType: presetType.isEmpty ? Meal.mealTypeForNow() : presetType),
    ));
    _loadAll();
  }

  Future<void> _addWater(int ml) async {
    try {
      final w = await ApiClient.instance.waterAdd(ml);
      setState(() => _water = w);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppModel>().user;
    final target = user?.dailyKcalTarget ?? 2200;
    final eaten = _meals.fold<int>(0, (s, m) => s + (m.totalKcal ?? 0));
    final gap = max(target - eaten + _activeEnergy, 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日概览'),
        actions: [
          IconButton(
            key: const Key('add-meal'),
            icon: const Icon(Icons.add_circle, color: Color(0xFF34D399)),
            onPressed: () => _openManual(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
          _CalorieRing(eaten: eaten, target: target),
          const SizedBox(height: 8),
          _MacroCards(eaten: eaten, target: target),
          const SizedBox(height: 14),
          Card(
            child: Column(children: [
              for (final (type, emoji, name) in Meal.slots) ...[
                Builder(builder: (context) {
                  final matches = _meals.where((m) => m.mealType == type).toList();
                  final kcal = matches.fold<int>(0, (s, m) => s + (m.totalKcal ?? 0));
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openManual(type),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(matches.isEmpty ? '点击拍照或手动记录' : '已记 ${matches.length} 项', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                        ])),
                        Text(matches.isEmpty ? '—' : '$kcal kcal', style: TextStyle(color: matches.isEmpty ? Theme.of(context).hintColor : AppColors.brandGreen, fontWeight: matches.isEmpty ? null : FontWeight.bold)),
                      ]),
                    ),
                  );
                }),
                if (type != 'SNACK') const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 10, children: [
                Row(children: [
                  const Text('💧', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('今日饮水', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${_water.totalMl} / ${_water.goalMl} ml', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ])),
                  if (_water.totalMl >= _water.goalMl)
                    const Text('已达标 🎉', style: TextStyle(fontSize: 12, color: AppColors.brandBlue, fontWeight: FontWeight.bold)),
                ]),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: min(_water.totalMl / max(_water.goalMl, 1), 1),
                    minHeight: 8,
                    backgroundColor: Theme.of(context).dividerColor,
                    color: AppColors.brandBlue,
                  ),
                ),
                Row(children: [
                  OutlinedButton(key: const Key('water-200'), onPressed: () => _addWater(200), style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandBlue, side: const BorderSide(color: AppColors.brandBlue)), child: const Text('＋200', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  OutlinedButton(key: const Key('water-500'), onPressed: () => _addWater(500), style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandBlue, side: const BorderSide(color: AppColors.brandBlue)), child: const Text('＋500', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Spacer(),
                  if (_water.totalMl > 0)
                    TextButton(onPressed: () => _addWater(-min(200, _water.totalMl)), child: const Text('撤销 200', style: TextStyle(fontSize: 12))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('已消耗 $_activeEnergy kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('步数 $_steps · 来自健康数据', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ])),
                Text('缺口 $gap', style: const TextStyle(fontSize: 12, color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  final int eaten, target;

  const _CalorieRing({required this.eaten, required this.target});

  @override
  Widget build(BuildContext context) {
    final progress = min(eaten / max(target, 1), 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        width: 200, height: 200,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 200, height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$eaten', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
            Text('/ $target kcal', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
          ]),
        ]),
      ),
    );
  }
}

class _MacroCards extends StatelessWidget {
  final int eaten, target;

  const _MacroCards({required this.eaten, required this.target});

  @override
  Widget build(BuildContext context) {
    final t = target.toDouble();
    final ratio = eaten / max(target, 1);
    final macros = [
      ('蛋白质', 0.25 * t * ratio, (0.25 * t).toInt(), AppColors.brandBlue),
      ('碳水', 0.50 * t * ratio, (0.50 * t).toInt(), AppColors.brandOrange),
      ('脂肪', 0.25 * t * ratio * 0.45, (0.27 * t).toInt(), AppColors.brandRed),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          for (final (i, (name, value, cap, color)) in macros.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: Column(spacing: 6, children: [
              Text('${value.toInt()}g', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text('$name ${value.toInt()}/${cap}g', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: min(value / max(cap.toDouble(), 1), 1),
                  minHeight: 5,
                  backgroundColor: Theme.of(context).dividerColor,
                  color: color,
                ),
              ),
            ])),
          ],
        ]),
      ),
    );
  }
}
