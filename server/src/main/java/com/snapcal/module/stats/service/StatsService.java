package com.snapcal.module.stats.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.snapcal.module.meal.entity.Meal;
import com.snapcal.module.meal.mapper.MealMapper;
import com.snapcal.security.UserContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class StatsService {

    private final MealMapper mealMapper;

    /** 最近 N 天每日摄入汇总 [{date, totalKcal}] */
    public List<Map<String, Object>> dailyIntake(int days) {
        Long userId = UserContext.requireUserId();
        int bounded = Math.min(Math.max(days, 1), 90);
        LocalDate today = LocalDate.now();
        LocalDate start = today.minusDays(bounded - 1L);

        // 初始化每天 0
        Map<LocalDate, Integer> totals = new LinkedHashMap<>();
        for (LocalDate d = start; !d.isAfter(today); d = d.plusDays(1)) {
            totals.put(d, 0);
        }

        List<Meal> meals = mealMapper.selectList(new LambdaQueryWrapper<Meal>()
                .eq(Meal::getUserId, userId)
                .ge(Meal::getEatTime, start.atStartOfDay())
                .lt(Meal::getEatTime, today.plusDays(1).atStartOfDay()));
        for (Meal meal : meals) {
            LocalDate day = meal.getEatTime().toLocalDate();
            totals.merge(day, meal.getTotalKcal() != null ? meal.getTotalKcal() : 0, Integer::sum);
        }

        List<Map<String, Object>> result = new ArrayList<>();
        totals.forEach((date, kcal) -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("date", date.toString());
            row.put("totalKcal", kcal);
            result.add(row);
        });
        return result;
    }
}
