import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../state/app_model.dart';

/// 周/月摄入与体重趋势。
class TrendsView extends StatefulWidget {
  const TrendsView({super.key});

  @override
  State<TrendsView> createState() => _TrendsViewState();
}

class _TrendsViewState extends State<TrendsView> {
  int _scope = 7;
  List<DailyIntake> _intake = const [];
  List<WeightRecord> _weights = const [];
  bool _loading = false;
  String? _error;
  int _requestGeneration = 0;

  int get _target => context.read<AppModel>().user?.dailyKcalTarget ?? 2200;

  double get _averageIntake {
    if (_intake.isEmpty) return 0;
    final total = _intake.fold<int>(0, (sum, day) => sum + day.totalKcal);
    return total / _intake.length;
  }

  int get _hitDays => _intake.where((day) => day.totalKcal <= _target).length;

  double? get _weightDelta {
    if (_weights.length < 2) return null;
    return _weights.last.weightKg - _weights.first.weightKg;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        ApiClient.instance.statsDaily(_scope),
        ApiClient.instance.weightList(_scope),
      ]);
      if (!mounted || generation != _requestGeneration) return;
      final intake = List<DailyIntake>.from(result[0] as List<DailyIntake>)
        ..sort((a, b) => a.date.compareTo(b.date));
      final weights = List<WeightRecord>.from(result[1] as List<WeightRecord>)
        ..sort((a, b) => a.recordDate.compareTo(b.recordDate));
      setState(() {
        _intake = intake;
        _weights = weights;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeScope(int scope) async {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _intake = const [];
      _weights = const [];
    });
    await _load();
  }

  Future<void> _recordWeight() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _WeightRecordSheet(),
    );
    if (saved == true && mounted) {
      await context.read<AppModel>().refreshMe();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('趋势')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('周')),
                ButtonSegment(value: 30, label: Text('月')),
              ],
              selected: {_scope},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _changeScope(selection.first),
            ),
            const SizedBox(height: 14),
            if (_loading && _intake.isEmpty && _weights.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null)
                _ErrorBanner(message: _error!, onRetry: _load),
              _buildStats(),
              const SizedBox(height: 14),
              _buildIntakeCard(),
              const SizedBox(height: 14),
              _buildWeightCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final delta = _weightDelta;
    final deltaText = delta == null
        ? '—'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}kg';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: _averageIntake.round().toString(),
            label: '日均摄入',
            color: AppColors.brandGreenDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: deltaText,
            label: '体重变化',
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$_hitDays/${_intake.length}',
            label: '达标天数',
            color: AppColors.brandOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildIntakeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '每日摄入',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '虚线 = 目标 $_target kcal',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_intake.isEmpty)
            const _ChartEmpty(message: '暂无摄入数据')
          else if (_scope == 7)
            SizedBox(height: 190, child: _buildIntakeChart())
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: math.max(
                  MediaQuery.sizeOf(context).width - 64,
                  _intake.length * 46.0,
                ),
                height: 190,
                child: _buildIntakeChart(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntakeChart() {
    final maxIntake = _intake.fold<int>(
      0,
      (max, day) => math.max(max, day.totalKcal),
    );
    final chartMax = math
        .max(2800, math.max(maxIntake + 400, _target + 600))
        .toDouble();
    final interval = math.max(500.0, (chartMax / 4).ceilToDouble());
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: chartMax.toDouble(),
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${_intake[group.x].totalKcal} kcal',
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _target.toDouble(),
              color: Theme.of(context).hintColor,
              strokeWidth: 1,
              dashArray: [5, 4],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value == 0 ? '0' : '${(value / 1000).toStringAsFixed(1)}k',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _intake.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _intake[index].shortLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < _intake.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: _intake[index].totalKcal.toDouble(),
                  width: _scope == 7 ? 18 : 15,
                  color: _intake[index].totalKcal > _target
                      ? AppColors.brandRed
                      : AppColors.brandGreen,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '体重趋势',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _recordWeight,
                icon: const Icon(Icons.add_circle, size: 18),
                label: const Text('记体重'),
              ),
            ],
          ),
          if (_weights.length >= 2)
            SizedBox(height: 160, child: _buildWeightChart())
          else if (_weights.length == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  '当前 ${_weights.first.weightKg.toStringAsFixed(1)} kg，\n再记录一次即可看到曲线',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            )
          else
            const _ChartEmpty(message: '还没有体重记录，点击“记体重”开始'),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    final minWeight = _weights
        .map((record) => record.weightKg)
        .reduce(math.min);
    final maxWeight = _weights
        .map((record) => record.weightKg)
        .reduce(math.max);
    final minY = (minWeight - 2).floorToDouble();
    final maxY = (maxWeight + 2).ceilToDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_weights.length - 1).toDouble(),
        minY: minY,
        maxY: maxY == minY ? minY + 4 : maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} kg',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: math.max(1, (_weights.length / 4).ceilToDouble()),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _weights.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDate(_weights[index].recordDate),
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < _weights.length; index++)
                FlSpot(index.toDouble(), _weights[index].weightKg),
            ],
            color: AppColors.brandBlue,
            barWidth: 3,
            isCurved: true,
            curveSmoothness: 0.25,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brandBlue.withAlpha(28),
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String raw) {
    final date = DateTime.tryParse(raw);
    return date == null ? raw : '${date.month}/${date.day}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightRecordSheet extends StatefulWidget {
  const _WeightRecordSheet();

  @override
  State<_WeightRecordSheet> createState() => _WeightRecordSheetState();
}

class _WeightRecordSheetState extends State<_WeightRecordSheet> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = context.read<AppModel>().user?.currentWeightKg;
    _controller = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final weight = double.parse(_controller.text.trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.weightSave(weight);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('记录体重', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('⚖️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('weight-input'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(hintText: '65.0'),
                    validator: (value) {
                      final weight = double.tryParse(value?.trim() ?? '');
                      if (weight == null) return '请输入有效体重';
                      if (weight <= 20 || weight >= 400) {
                        return '请输入 20–400 kg 之间的体重';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _saving ? null : _save(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 10, top: 18),
                  child: Text('kg'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
