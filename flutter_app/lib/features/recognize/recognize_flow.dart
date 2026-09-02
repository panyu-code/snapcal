import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/food_emoji.dart';
import '../../core/models.dart';
import '../../core/theme.dart' show AppColors;
import '../search/food_search_sheet.dart';

Future<void> openRecognizeFlow(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('拍照识别'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('从相册选择'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ]),
    ),
  );
  if (source == null) return;
  final photo = await ImagePicker().pickImage(source: source, imageQuality: 82, maxWidth: 1600, maxHeight: 1600);
  if (photo == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => RecognizeFlowView(image: File(photo.path)),
  ));
}

class _RecognizeDraft {
  String name;
  int originalWeight, originalKcal;
  double originalProtein, originalCarbs, originalFat;
  final TextEditingController controller;

  _RecognizeDraft.fromResult(RecognizeItem item)
      : name = item.name,
        originalWeight = item.weightG <= 0 ? 1 : item.weightG,
        originalKcal = item.kcal,
        originalProtein = item.proteinG ?? 0,
        originalCarbs = item.carbsG ?? 0,
        originalFat = item.fatG ?? 0,
        controller = TextEditingController(text: '${item.weightG}');

  int get weight => int.tryParse(controller.text) ?? 0;
  int get kcal => (originalKcal * weight / originalWeight).round();
  double get protein => _round1(originalProtein * weight / originalWeight);
  double get carbs => _round1(originalCarbs * weight / originalWeight);
  double get fat => _round1(originalFat * weight / originalWeight);

  void replaceWithFood(Food food) {
    name = food.name;
    originalWeight = 100;
    originalKcal = food.kcalPer100g ?? 0;
    originalProtein = food.proteinPer100g ?? 0;
    originalCarbs = food.carbsPer100g ?? 0;
    originalFat = food.fatPer100g ?? 0;
  }

  MealSaveItem toSaveItem() => MealSaveItem(
        foodName: name, weightG: weight, kcal: kcal, proteinG: protein,
        carbsG: carbs, fatG: fat, source: 'AI',
      );

  static double _round1(double v) => (v * 10).round() / 10;
}

/// 拍照识别结果流: 上传识别 → 克重调整/删项/替换 → 保存
class RecognizeFlowView extends StatefulWidget {
  final File image;

  const RecognizeFlowView({super.key, required this.image});

  @override
  State<RecognizeFlowView> createState() => _RecognizeFlowViewState();
}

class _RecognizeFlowViewState extends State<RecognizeFlowView> with SingleTickerProviderStateMixin {
  RecognizeResult? _result;
  List<_RecognizeDraft> _items = [];
  String _mealType = Meal.mealTypeForNow();
  bool _loading = true, _saving = false;
  String? _error;
  late AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _recognize();
  }

  @override
  void dispose() {
    _scan.dispose();
    for (final i in _items) {
      i.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _recognize() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiClient.instance.recognize(widget.image);
      if (!mounted) return;
      setState(() {
        _result = result;
        _items = result.items.map(_RecognizeDraft.fromResult).toList();
        _loading = false;
      });
      _scan.stop();
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
      _scan.stop();
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.saveMeal(MealSaveReq(
        mealType: _mealType,
        photoUrl: _result?.image,
        items: _items.map((e) => e.toSaveItem()).toList(),
      ));
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'AI 识别中' : '确认识别结果'),
        actions: [
          if (!_loading)
            TextButton(
              key: const Key('save-recognize'),
              onPressed: _items.isEmpty || _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator(strokeWidth: 2) : const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loading ? _loadingView() : (_error != null ? _errorView() : _resultView()),
    );
  }

  Widget _loadingView() {
    return Stack(fit: StackFit.expand, children: [
      Image.file(widget.image, fit: BoxFit.cover),
      Container(color: Colors.black.withAlpha(110)),
      AnimatedBuilder(
        animation: _scan,
        builder: (_, __) => Positioned(
          top: MediaQuery.of(context).size.height * .7 * _scan.value,
          left: 20, right: 20,
          child: Container(height: 2, decoration: BoxDecoration(boxShadow: const [BoxShadow(color: AppColors.brandGreen, blurRadius: 8)], color: AppColors.brandGreen)),
        ),
      ),
      const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: AppColors.brandGreen), SizedBox(height: 14),
        Text('GLM-5.3-flash 正在分析餐盘...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ])),
    ]);
  }

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.brandRed, size: 48),
        const SizedBox(height: 12), Text(_error ?? '识别失败'),
        const SizedBox(height: 16), FilledButton(onPressed: _recognize, child: const Text('重新识别')),
      ]));

  Widget _resultView() {
    final total = _items.fold<int>(0, (s, i) => s + i.kcal);
    return ListView(padding: const EdgeInsets.all(16), children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(widget.image, height: 210, fit: BoxFit.cover)),
      const SizedBox(height: 12),
      Row(spacing: 8, children: [
        for (final (type, emoji, name) in Meal.slots)
          Expanded(child: ChoiceChip(
            selected: _mealType == type,
            label: Text('$emoji $name', style: const TextStyle(fontSize: 11)),
            onSelected: (_) => setState(() => _mealType = type),
          )),
      ]),
      const SizedBox(height: 12),
      Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('识别食物', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('合计 $total kcal', style: const TextStyle(color: AppColors.brandGreen, fontWeight: FontWeight.bold)),
          ]),
          const Divider(),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Text(FoodEmoji.forFood(item.name), style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: InkWell(
                  onTap: () => showFoodSearchSheet(context, onSelect: (food) => setState(() => item.replaceWithFood(food))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold))), const Icon(Icons.refresh, size: 16, color: AppColors.brandGreen)]),
                    Text('${item.kcal} kcal · 蛋白${item.protein}g 碳水${item.carbs}g 脂肪${item.fat}g', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                  ]),
                )),
                SizedBox(width: 55, child: TextField(
                  controller: item.controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                )),
                const Text('g'),
                IconButton(icon: const Icon(Icons.remove_circle, color: AppColors.brandRed), onPressed: () => setState(() => _items.remove(item))),
              ]),
            ),
        ]),
      )),
      const SizedBox(height: 8),
      Text('识别引擎: ${_result?.engine ?? 'GLM'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
    ]);
  }
}
