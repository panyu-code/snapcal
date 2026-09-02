import 'package:health/health.dart';

/// 健康数据: 步数 + 活动消耗 (iOS HealthKit / Android Health Connect)
/// 权限被拒或平台不支持时静默降级为 0, 不阻塞主流程
class HealthManager {
  HealthManager._();
  static final instance = HealthManager._();

  final _health = Health();
  bool _authorized = false;

  static const _types = [HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];

  Future<void> requestAuthorization() async {
    if (_authorized) return;
    try {
      _authorized = await _health.requestAuthorization(_types);
    } catch (_) {
      _authorized = false;
    }
  }

  Future<int> todaySteps() async {
    if (!_authorized) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(types: [HealthDataType.STEPS], startTime: midnight, endTime: now);
      final total = data.fold<int>(0, (sum, p) => sum + (p.value as NumericHealthValue).numericValue.toInt());
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<int> todayActiveEnergy() async {
    if (!_authorized) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(types: [HealthDataType.ACTIVE_ENERGY_BURNED], startTime: midnight, endTime: now);
      final total = data.fold<int>(0, (sum, p) => sum + (p.value as NumericHealthValue).numericValue.toInt());
      return total;
    } catch (_) {
      return 0;
    }
  }
}
