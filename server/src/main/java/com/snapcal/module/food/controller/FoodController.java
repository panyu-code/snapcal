package com.snapcal.module.food.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.snapcal.common.result.Result;
import com.snapcal.module.food.entity.Food;
import com.snapcal.module.food.favorite.FoodFavorite;
import com.snapcal.module.food.mapper.FoodFavoriteMapper;
import com.snapcal.module.food.mapper.FoodMapper;
import com.snapcal.module.meal.entity.Meal;
import com.snapcal.module.meal.entity.MealItem;
import com.snapcal.module.meal.mapper.MealItemMapper;
import com.snapcal.module.meal.mapper.MealMapper;
import com.snapcal.security.UserContext;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/food")
@RequiredArgsConstructor
public class FoodController {

    private final FoodMapper foodMapper;
    private final FoodFavoriteMapper favoriteMapper;
    private final MealMapper mealMapper;
    private final MealItemMapper mealItemMapper;

    /** 搜索 (替换食物用, 最多20条) */
    @GetMapping("/search")
    public Result<List<Food>> search(@RequestParam String kw) {
        if (!StringUtils.hasText(kw) || kw.length() > 30) {
            return Result.success(List.of());
        }
        List<Food> foods = foodMapper.selectList(new LambdaQueryWrapper<Food>()
                .like(Food::getName, kw)
                .orderByAsc(Food::getName)
                .last("LIMIT 20"));
        return Result.success(foods);
    }

    /** 食物库分页浏览 (名称/类别筛选) */
    @GetMapping("/list")
    public Result<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "50") long size,
            @RequestParam(required = false) String kw,
            @RequestParam(required = false) String category) {
        long boundedSize = Math.min(Math.max(size, 1), 100);
        LambdaQueryWrapper<Food> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(kw)) {
            wrapper.like(Food::getName, kw);
        }
        if (StringUtils.hasText(category)) {
            wrapper.eq(Food::getCategory, category);
        }
        wrapper.orderByAsc(Food::getId);
        IPage<Food> page = foodMapper.selectPage(new Page<>(current, boundedSize), wrapper);
        return Result.success(Map.of(
                "records", page.getRecords(),
                "total", page.getTotal(),
                "current", page.getCurrent(),
                "size", page.getSize()));
    }

    /** 食物库分类列表 */
    @GetMapping("/categories")
    public Result<List<String>> categories() {
        List<Food> foods = foodMapper.selectList(null);
        List<String> cats = foods.stream()
                .map(Food::getCategory)
                .filter(StringUtils::hasText)
                .distinct()
                .sorted()
                .toList();
        return Result.success(cats);
    }

    // ==================== 收藏 ====================

    /** 我的收藏食物 (按收藏时间倒序) */
    @GetMapping("/favorites")
    public Result<List<Food>> favorites() {
        Long userId = UserContext.requireUserId();
        List<FoodFavorite> favs = favoriteMapper.selectList(new LambdaQueryWrapper<FoodFavorite>()
                .eq(FoodFavorite::getUserId, userId)
                .orderByDesc(FoodFavorite::getId)
                .last("LIMIT 60"));
        if (favs.isEmpty()) {
            return Result.success(List.of());
        }
        List<Long> ids = favs.stream().map(FoodFavorite::getFoodId).toList();
        Map<Long, Food> byId = foodMapper.selectBatchIds(ids).stream()
                .collect(Collectors.toMap(Food::getId, f -> f));
        // 保持收藏顺序, 已下架的食物跳过
        List<Food> result = ids.stream().map(byId::get).filter(Objects::nonNull).toList();
        return Result.success(result);
    }

    /** 收藏 / 取消收藏 (幂等切换) */
    @PostMapping("/favorites/{foodId}/toggle")
    public Result<Map<String, Object>> toggleFavorite(@PathVariable Long foodId) {
        Long userId = UserContext.requireUserId();
        Food food = foodMapper.selectById(foodId);
        if (food == null) {
            return Result.error(10010, "食物不存在");
        }
        FoodFavorite existing = favoriteMapper.selectOne(new LambdaQueryWrapper<FoodFavorite>()
                .eq(FoodFavorite::getUserId, userId)
                .eq(FoodFavorite::getFoodId, foodId)
                .last("LIMIT 1"));
        boolean favored;
        if (existing != null) {
            favoriteMapper.deleteById(existing.getId());
            favored = false;
        } else {
            FoodFavorite fav = new FoodFavorite();
            fav.setUserId(userId);
            fav.setFoodId(foodId);
            favoriteMapper.insert(fav);
            favored = true;
        }
        return Result.success(Map.of("favored", favored));
    }

    /** 常吃食物 (最近记过的食物, 去重按最近优先, 最多12个) */
    @GetMapping("/recent")
    public Result<List<Food>> recent() {
        Long userId = UserContext.requireUserId();
        List<Meal> meals = mealMapper.selectList(new LambdaQueryWrapper<Meal>()
                .eq(Meal::getUserId, userId)
                .orderByDesc(Meal::getId)
                .last("LIMIT 40"));
        if (meals.isEmpty()) {
            return Result.success(List.of());
        }
        List<Long> mealIds = meals.stream().map(Meal::getId).toList();
        List<MealItem> items = mealItemMapper.selectList(new LambdaQueryWrapper<MealItem>()
                .in(MealItem::getMealId, mealIds)
                .orderByDesc(MealItem::getId)
                .last("LIMIT 300"));
        LinkedHashSet<String> names = items.stream()
                .map(MealItem::getFoodName)
                .filter(StringUtils::hasText)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        if (names.isEmpty()) {
            return Result.success(List.of());
        }
        List<String> topNames = names.stream().limit(30).toList();
        Map<String, Food> byName = foodMapper.selectList(new LambdaQueryWrapper<Food>()
                        .in(Food::getName, topNames))
                .stream()
                .collect(Collectors.toMap(Food::getName, f -> f, (a, b) -> a));
        List<Food> result = topNames.stream().map(byName::get)
                .filter(Objects::nonNull)
                .limit(12)
                .toList();
        return Result.success(result);
    }
}
