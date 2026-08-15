package com.snapcal.module.food.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
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

@RestController
@RequestMapping("/food")
@RequiredArgsConstructor
public class FoodController {

    private final FoodMapper foodMapper;

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
}
