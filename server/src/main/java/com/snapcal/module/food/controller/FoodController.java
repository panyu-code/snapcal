package com.snapcal.module.food.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.snapcal.common.result.Result;
import com.snapcal.module.food.entity.Food;
import com.snapcal.module.food.mapper.FoodMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/food")
@RequiredArgsConstructor
public class FoodController {

    private final FoodMapper foodMapper;

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
}
