// 后端数据模型 (与 iOS 版 Models/MealModels 对齐)

// MARK: 统一响应

class ApiResult<T> {
  final int code;
  final String? message;
  final T? data;

  ApiResult({required this.code, this.message, this.data});

  factory ApiResult.fromJson(Map<String, dynamic> j, T Function(dynamic)? parse) =>
      ApiResult(code: j['code'] as int, message: j['message'] as String?, data: j['data'] == null ? null : parse?.call(j['data']));
}

// MARK: 用户

class User {
  final int id;
  final String? nickname, avatar, targetType;
  final int? birthYear, dailyKcalTarget;
  final double? heightCm, goalWeightKg, currentWeightKg;
  final bool? isPro;

  User({required this.id, this.nickname, this.avatar, this.targetType, this.birthYear, this.dailyKcalTarget, this.heightCm, this.goalWeightKg, this.currentWeightKg, this.isPro});

  factory User.fromJson(Map<String, dynamic> j) => User(
      id: j['id'] as int,
      nickname: j['nickname'] as String?,
      avatar: j['avatar'] as String?,
      targetType: j['targetType'] as String?,
      birthYear: j['birthYear'] as int?,
      dailyKcalTarget: j['dailyKcalTarget'] as int?,
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      goalWeightKg: (j['goalWeightKg'] as num?)?.toDouble(),
      currentWeightKg: (j['currentWeightKg'] as num?)?.toDouble(),
      isPro: j['isPro'] as bool?);

  Map<String, dynamic> toJson() => {'id': id, 'nickname': nickname, 'avatar': avatar, 'targetType': targetType, 'birthYear': birthYear, 'dailyKcalTarget': dailyKcalTarget, 'heightCm': heightCm, 'goalWeightKg': goalWeightKg, 'currentWeightKg': currentWeightKg, 'isPro': isPro};

  String get targetTypeName => switch (targetType) { 'GAIN' => '增肌', 'KEEP' => '维持', _ => '减脂' };
}

// MARK: 餐次

class MealItem {
  final String foodName;
  final int weightG;
  final int? kcal;
  final double? proteinG, carbsG, fatG;
  final String? source;

  MealItem({required this.foodName, required this.weightG, this.kcal, this.proteinG, this.carbsG, this.fatG, this.source});

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
      foodName: j['foodName'] as String,
      weightG: (j['weightG'] as num).toInt(),
      kcal: (j['kcal'] as num?)?.toInt(),
      proteinG: (j['proteinG'] as num?)?.toDouble(),
      carbsG: (j['carbsG'] as num?)?.toDouble(),
      fatG: (j['fatG'] as num?)?.toDouble(),
      source: j['source'] as String?);

  Map<String, dynamic> toJson() => {
    'foodName': foodName,
    'weightG': weightG,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'source': source,
  };
}

class Meal {
  final int? id;
  final String mealType;
  final String? photoUrl, note, eatTime;
  final int? totalKcal;
  final double? proteinG, carbsG, fatG;
  final List<MealItem>? items;

  Meal({this.id, required this.mealType, this.photoUrl, this.note, this.eatTime, this.totalKcal, this.proteinG, this.carbsG, this.fatG, this.items});

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
      id: j['id'] as int?,
      mealType: j['mealType'] as String,
      photoUrl: j['photoUrl'] as String?,
      note: j['note'] as String?,
      eatTime: j['eatTime'] as String?,
      totalKcal: (j['totalKcal'] as num?)?.toInt(),
      proteinG: (j['proteinG'] as num?)?.toDouble(),
      carbsG: (j['carbsG'] as num?)?.toDouble(),
      fatG: (j['fatG'] as num?)?.toDouble(),
      items: (j['items'] as List?)?.map((e) => MealItem.fromJson(e)).toList());

  Map<String, dynamic> toJson() => {
    'id': id,
    'mealType': mealType,
    'photoUrl': photoUrl,
    'note': note,
    'eatTime': eatTime,
    'totalKcal': totalKcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'items': items?.map((e) => e.toJson()).toList(),
  };

  String get mealTypeName => switch (mealType) { 'BREAKFAST' => '早餐', 'LUNCH' => '午餐', 'DINNER' => '晚餐', _ => '加餐' };

  static const slots = [('BREAKFAST', '🥣', '早餐'), ('LUNCH', '🍽️', '午餐'), ('DINNER', '🍜', '晚餐'), ('SNACK', '🍎', '加餐')];

  static String mealTypeForNow() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 10) return 'BREAKFAST';
    if (h >= 10 && h < 14) return 'LUNCH';
    if (h >= 14 && h < 21) return 'DINNER';
    return 'SNACK';
  }
}

class MealSaveItem {
  final String foodName;
  final int weightG;
  final int? kcal;
  final double? proteinG, carbsG, fatG;
  final String? source;

  MealSaveItem({required this.foodName, required this.weightG, this.kcal, this.proteinG, this.carbsG, this.fatG, this.source});

  Map<String, dynamic> toJson() => {'foodName': foodName, 'weightG': weightG, 'kcal': kcal, 'proteinG': proteinG, 'carbsG': carbsG, 'fatG': fatG, 'source': source};
}

class MealSaveReq {
  final String mealType;
  final String? photoUrl, eatTime, note;
  final List<MealSaveItem> items;

  MealSaveReq({required this.mealType, this.photoUrl, this.eatTime, this.note, required this.items});

  Map<String, dynamic> toJson() => {'mealType': mealType, 'photoUrl': photoUrl, 'eatTime': eatTime, 'note': note, 'items': items.map((e) => e.toJson()).toList()};
}

class MealUpdateReq {
  final String mealType;
  final String note;
  final List<MealSaveItem> items;

  MealUpdateReq({required this.mealType, required this.note, required this.items});

  Map<String, dynamic> toJson() => {'mealType': mealType, 'note': note, 'items': items.map((e) => e.toJson()).toList()};
}

// MARK: 食物

class Food {
  final int id;
  final String name;
  final String? emoji, imageUrl, category;
  final int? kcalPer100g;
  final double? proteinPer100g, carbsPer100g, fatPer100g;

  Food({required this.id, required this.name, this.emoji, this.imageUrl, this.category, this.kcalPer100g, this.proteinPer100g, this.carbsPer100g, this.fatPer100g});

  factory Food.fromJson(Map<String, dynamic> j) => Food(
      id: j['id'] as int,
      name: j['name'] as String,
      emoji: j['emoji'] as String?,
      imageUrl: j['imageUrl'] as String?,
      category: j['category'] as String?,
      kcalPer100g: (j['kcalPer100g'] as num?)?.toInt(),
      proteinPer100g: (j['proteinPer100g'] as num?)?.toDouble(),
      carbsPer100g: (j['carbsPer100g'] as num?)?.toDouble(),
      fatPer100g: (j['fatPer100g'] as num?)?.toDouble());
}

// MARK: 饮水

class WaterToday {
  final String date;
  final int totalMl, goalMl;

  WaterToday({required this.date, required this.totalMl, required this.goalMl});

  factory WaterToday.fromJson(Map<String, dynamic> j) => WaterToday(date: j['date'] as String, totalMl: (j['totalMl'] as num).toInt(), goalMl: (j['goalMl'] as num).toInt());
}

// MARK: 趋势

class DailyIntake {
  final String date;
  final int totalKcal;

  DailyIntake({required this.date, required this.totalKcal});

  factory DailyIntake.fromJson(Map<String, dynamic> j) => DailyIntake(date: j['date'] as String, totalKcal: (j['totalKcal'] as num).toInt());

  String get shortLabel {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    if (d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day) return '今';
    return '${d.day}';
  }
}

class WeightRecord {
  final int? id, userId;
  final double weightKg;
  final String recordDate;

  WeightRecord({this.id, this.userId, required this.weightKg, required this.recordDate});

  factory WeightRecord.fromJson(Map<String, dynamic> j) => WeightRecord(
      id: j['id'] as int?,
      userId: j['userId'] as int?,
      weightKg: (j['weightKg'] as num).toDouble(),
      recordDate: (j['recordDate'] ?? j['record_date'] ?? '') as String);
}

// MARK: 识别结果

class RecognizeItem {
  final String name;
  final int weightG, kcal;
  final double? proteinG, carbsG, fatG, confidence;

  RecognizeItem({required this.name, required this.weightG, required this.kcal, this.proteinG, this.carbsG, this.fatG, this.confidence});

  factory RecognizeItem.fromJson(Map<String, dynamic> j) => RecognizeItem(
      name: j['name'] as String,
      weightG: (j['weightG'] ?? j['weight_g'] as num?)?.toInt() ?? 100,
      kcal: (j['kcal'] as num?)?.toInt() ?? 0,
      proteinG: (j['proteinG'] ?? j['protein_g'] as num?)?.toDouble(),
      carbsG: (j['carbsG'] ?? j['carbs_g'] as num?)?.toDouble(),
      fatG: (j['fatG'] ?? j['fat_g'] as num?)?.toDouble(),
      confidence: (j['confidence'] as num?)?.toDouble());
}

class RecognizeResult {
  final String? image, engine;
  final List<RecognizeItem> items;

  RecognizeResult({this.image, this.engine, required this.items});

  factory RecognizeResult.fromJson(Map<String, dynamic> j) => RecognizeResult(
      image: j['image'] as String?,
      engine: j['engine'] as String?,
      items: (j['items'] as List? ?? []).map((e) => RecognizeItem.fromJson(e)).toList());
}

// MARK: 日期工具

String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const weekdaysZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String dayTitleZh(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return key;
  final now = DateTime.now();
  final today = dateKey(now), yesterday = dateKey(now.subtract(const Duration(days: 1)));
  final base = '${d.month}月${d.day}日 ${weekdaysZh[d.weekday - 1]}';
  if (key == today) return '今天 · $base';
  if (key == yesterday) return '昨天 · $base';
  return base;
}
