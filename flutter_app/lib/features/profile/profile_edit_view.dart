import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../state/app_model.dart';

/// 编辑基础资料与体重目标；热量目标由后端重新计算。
class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _birthYearController;
  late final TextEditingController _heightController;
  late final TextEditingController _currentWeightController;
  late final TextEditingController _goalWeightController;

  int _gender = 1;
  String _targetType = 'LOSE';
  String _pace = 'MID';
  double _activityFactor = 1.2;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppModel>().user;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _birthYearController = TextEditingController(
      text: (user?.birthYear ?? 1998).toString(),
    );
    _heightController = TextEditingController(
      text: _numberText(user?.heightCm ?? 172),
    );
    _currentWeightController = TextEditingController(
      text: _numberText(user?.currentWeightKg ?? 65),
    );
    _goalWeightController = TextEditingController(
      text: _numberText(user?.goalWeightKg ?? 60),
    );
    _targetType = switch (user?.targetType) {
      'KEEP' => 'KEEP',
      'GAIN' => 'GAIN',
      _ => 'LOSE',
    };
  }

  static String _numberText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthYearController.dispose();
    _heightController.dispose();
    _currentWeightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  String? _validateNumber(
    String? raw,
    String label,
    double minimum,
    double maximum,
  ) {
    final value = double.tryParse(raw?.trim() ?? '');
    if (value == null) return '请输入有效的$label';
    if (value < minimum || value > maximum) {
      return '$label需在 ${_numberText(minimum)}–${_numberText(maximum)} 之间';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final app = context.read<AppModel>();
    try {
      final updated = await ApiClient.instance.updateProfile({
        'nickname': _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        'gender': _gender,
        'birthYear': int.parse(_birthYearController.text.trim()),
        'heightCm': double.parse(_heightController.text.trim()),
        'currentWeightKg': double.parse(_currentWeightController.text.trim()),
        'goalWeightKg': double.parse(_goalWeightController.text.trim()),
        'targetType': _targetType,
        'pace': _pace,
        'activityFactor': _activityFactor,
      });
      app.user = updated;
      await app.refreshMe();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = error is ApiException ? error.message : '保存失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _sectionTitle(context, '基础资料'),
            TextFormField(
              controller: _nicknameController,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '昵称',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: '性别'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('男')),
                DropdownMenuItem(value: 2, child: Text('女')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _gender = value ?? 1),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _birthYearController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '出生年份'),
              validator: (value) {
                final year = int.tryParse(value?.trim() ?? '');
                if (year == null) return '请输入有效的出生年份';
                if (year < 1920 || year > 2020) return '出生年份需在 1920–2020 之间';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _measurementField(
              controller: _heightController,
              label: '身高',
              unit: 'cm',
              minimum: 80,
              maximum: 250,
            ),
            const SizedBox(height: 12),
            _measurementField(
              controller: _currentWeightController,
              label: '当前体重',
              unit: 'kg',
              minimum: 25,
              maximum: 300,
            ),
            _sectionTitle(context, '目标'),
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              decoration: const InputDecoration(labelText: '目标类型'),
              items: const [
                DropdownMenuItem(value: 'LOSE', child: Text('减脂')),
                DropdownMenuItem(value: 'KEEP', child: Text('维持')),
                DropdownMenuItem(value: 'GAIN', child: Text('增肌')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _targetType = value ?? 'LOSE'),
            ),
            const SizedBox(height: 12),
            _measurementField(
              controller: _goalWeightController,
              label: '目标体重',
              unit: 'kg',
              minimum: 25,
              maximum: 300,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _pace,
              decoration: const InputDecoration(labelText: '速度'),
              items: const [
                DropdownMenuItem(value: 'SLOW', child: Text('慢速（±250 kcal）')),
                DropdownMenuItem(value: 'MID', child: Text('中速（±500 kcal）')),
                DropdownMenuItem(value: 'FAST', child: Text('快速（±750 kcal）')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _pace = value ?? 'MID'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: _activityFactor,
              decoration: const InputDecoration(labelText: '活动系数'),
              items: const [
                DropdownMenuItem(value: 1.2, child: Text('久坐（1.2）')),
                DropdownMenuItem(value: 1.375, child: Text('轻度活动（1.375）')),
                DropdownMenuItem(value: 1.55, child: Text('中度活动（1.55）')),
                DropdownMenuItem(value: 1.725, child: Text('高强度活动（1.725）')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _activityFactor = value ?? 1.2),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _measurementField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required double minimum,
    required double maximum,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: unit),
      validator: (value) => _validateNumber(value, label, minimum, maximum),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
