import 'package:flutter_test/flutter_test.dart';

import 'package:snapcal/core/food_emoji.dart';
import 'package:snapcal/core/models.dart';
import 'package:snapcal/core/reminder_manager.dart';

void main() {
  group('FoodEmoji', () {
    test('exact and keyword fallback', () {
      expect(FoodEmoji.forFood('米饭'), '🍚');
      expect(FoodEmoji.forFood('乐事薯片'), '🍠');
      expect(FoodEmoji.forFood('未知食物'), '🍽️');
    });
  });

  group('Models', () {
    test('meal and item JSON round trip', () {
      final meal = Meal(
        id: 1,
        mealType: 'LUNCH',
        totalKcal: 232,
        items: [MealItem(foodName: '米饭', weightG: 200, kcal: 232, source: 'MANUAL')],
      );
      final decoded = Meal.fromJson(meal.toJson());
      expect(decoded.id, 1);
      expect(decoded.mealTypeName, '午餐');
      expect(decoded.items!.single.foodName, '米饭');
      expect(decoded.items!.single.weightG, 200);
    });

    test('meal type follows local hour', () {
      expect({'BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'}, contains(Meal.mealTypeForNow()));
    });
  });

  group('ReminderManager', () {
    test('parses valid times and ignores invalid values', () {
      expect(ReminderManager.parseTimes('8:00,12:30,18:05'), [(8, 0), (12, 30), (18, 5)]);
      expect(ReminderManager.parseTimes('8:00,bad,25:00,12:70'), [(8, 0)]);
    });
  });
}
