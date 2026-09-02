import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

/// 餐次详情：照片、备注、营养汇总、食物明细及编辑/删除操作。
class MealDetailView extends StatefulWidget {
  final Meal meal;

  const MealDetailView({super.key, required this.meal});

  @override
  State<MealDetailView> createState() => _MealDetailViewState();
}

class _MealDetailViewState extends State<MealDetailView> {
  late Meal _meal = widget.meal;
  final _noteController = TextEditingController();
  final List<_EditableMealItem> _editItems = [];

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;
  String _editMealType = '';

  int get _editTotalKcal =>
      _editItems.fold(0, (total, item) => total + item.kcal);
  double get _editTotalProtein =>
      _editItems.fold(0, (total, item) => total + item.proteinG);
  double get _editTotalCarbs =>
      _editItems.fold(0, (total, item) => total + item.carbsG);
  double get _editTotalFat =>
      _editItems.fold(0, (total, item) => total + item.fatG);

  @override
  void dispose() {
    _noteController.dispose();
    _disposeEditItems();
    super.dispose();
  }

  void _disposeEditItems() {
    for (final item in _editItems) {
      item.dispose();
    }
    _editItems.clear();
  }

  void _beginEdit() {
    _disposeEditItems();
    _editMealType = _meal.mealType;
    _noteController.text = _meal.note ?? '';
    _editItems.addAll((_meal.items ?? []).map(_EditableMealItem.fromMealItem));
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    _disposeEditItems();
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final mealId = _meal.id;
    if (mealId == null || _editItems.isEmpty || _saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final request = MealUpdateReq(
        mealType: _editMealType,
        note: _noteController.text,
        items: _editItems
            .map(
              (item) => MealSaveItem(
                foodName: item.foodName,
                weightG: item.weightG,
                kcal: item.kcal,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                source: item.source,
              ),
            )
            .toList(),
      );
      final updated = await ApiClient.instance.updateMeal(mealId, request);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _disposeEditItems();
      setState(() {
        _meal = updated;
        _editing = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('保存失败：$error');
    }
  }

  Future<void> _confirmDelete() async {
    if (_meal.id == null || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ApiClient.instance.deleteMeal(_meal.id!);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _showMessage('删除失败：$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving && !_deleting,
      child: Scaffold(
        appBar: AppBar(
          leading: _editing
              ? TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: const Text('取消'),
                )
              : null,
          leadingWidth: _editing ? 72 : null,
          title: Text(_editing ? '编辑餐次' : '餐次详情'),
          actions: [
            if (_editing)
              TextButton(
                key: const Key('save-meal-edit'),
                onPressed: _editItems.isEmpty || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              )
            else
              TextButton(
                key: const Key('edit-meal'),
                onPressed: _meal.id == null ? null : _beginEdit,
                child: const Text('编辑'),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _photoHeader(),
            if (!_editing && (_meal.note?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              _noteCard(),
            ],
            const SizedBox(height: 16),
            _macroSummary(),
            const SizedBox(height: 16),
            if (_editing) _editorCard() else _itemsCard(),
            if (!_editing && _meal.id != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  key: const Key('delete-meal'),
                  onPressed: _deleting ? null : _confirmDelete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandRed.withAlpha(31),
                    foregroundColor: AppColors.brandRed,
                    disabledBackgroundColor: AppColors.brandRed.withAlpha(18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_deleting ? '删除中…' : '删除这条记录'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoHeader() {
    final photoUrl = _meal.photoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 40)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meal.mealTypeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _eatTimeText,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : ColoredBox(
                      color: Theme.of(context).cardColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: Theme.of(context).cardColor,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_meal.mealTypeName} · $_eatTimeText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes, size: 16, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _meal.note!,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroSummary() {
    return Row(
      children: [
        Expanded(
          child: _macroCard(
            '热量',
            '${_editing ? _editTotalKcal : (_meal.totalKcal ?? 0)}',
            'kcal',
            AppColors.brandGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _macroCard(
            '蛋白质',
            (_editing ? _editTotalProtein : (_meal.proteinG ?? 0))
                .toStringAsFixed(0),
            'g',
            AppColors.brandBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _macroCard(
            '碳水',
            (_editing ? _editTotalCarbs : (_meal.carbsG ?? 0)).toStringAsFixed(
              0,
            ),
            'g',
            AppColors.brandOrange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _macroCard(
            '脂肪',
            (_editing ? _editTotalFat : (_meal.fatG ?? 0)).toStringAsFixed(0),
            'g',
            AppColors.brandRed,
          ),
        ),
      ],
    );
  }

  Widget _macroCard(String label, String value, String unit, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            unit,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10),
          ),
          Text(
            label,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    final items = _meal.items ?? [];
    return AppCard(
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '无明细',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).dividerColor,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[index].foodName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${items[index].weightG}g · ${items[index].source == 'AI' ? 'AI 识别' : '手动'}',
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${items[index].kcal ?? 0} kcal',
                          style: const TextStyle(
                            color: AppColors.brandGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  Widget _editorCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (type, emoji, name) in Meal.slots)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _saving
                          ? null
                          : () => setState(() => _editMealType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _editMealType == type
                              ? AppColors.brandGreen.withAlpha(46)
                              : Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emoji),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _editMealType == type
                                      ? AppColors.brandGreen
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('meal-note'),
            controller: _noteController,
            enabled: !_saving,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(hintText: '添加备注 (选填)'),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          for (final item in _editItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.foodName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${item.kcal} kcal',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      key: ValueKey(item),
                      controller: item.weightController,
                      enabled: !_saving,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'g',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 11,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除食物',
                    onPressed: _saving
                        ? null
                        : () {
                            item.dispose();
                            setState(() => _editItems.remove(item));
                          },
                    icon: Icon(
                      Icons.remove_circle,
                      color: AppColors.brandRed.withAlpha(190),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _eatTimeText {
    final raw = _meal.eatTime;
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return '';
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}

/// 保存原始每克营养密度，克重变化时据此实时缩放。
class _EditableMealItem {
  final String foodName;
  final String source;
  final TextEditingController weightController;
  final double _kcalPerG;
  final double _proteinPerG;
  final double _carbsPerG;
  final double _fatPerG;

  _EditableMealItem._({
    required this.foodName,
    required this.source,
    required this.weightController,
    required this._kcalPerG,
    required this._proteinPerG,
    required this._carbsPerG,
    required this._fatPerG,
  });

  factory _EditableMealItem.fromMealItem(MealItem item) {
    final originalWeight = item.weightG > 0 ? item.weightG.toDouble() : 1.0;
    return _EditableMealItem._(
      foodName: item.foodName,
      source: item.source ?? 'AI',
      weightController: TextEditingController(text: '${item.weightG}'),
      kcalPerG: (item.kcal ?? 0) / originalWeight,
      proteinPerG: (item.proteinG ?? 0) / originalWeight,
      carbsPerG: (item.carbsG ?? 0) / originalWeight,
      fatPerG: (item.fatG ?? 0) / originalWeight,
    );
  }

  int get weightG => int.tryParse(weightController.text) ?? 0;
  int get kcal => (_kcalPerG * weightG).round();
  double get proteinG => _oneDecimal(_proteinPerG * weightG);
  double get carbsG => _oneDecimal(_carbsPerG * weightG);
  double get fatG => _oneDecimal(_fatPerG * weightG);

  static double _oneDecimal(double value) => (value * 10).round() / 10;

  void dispose() => weightController.dispose();
}
