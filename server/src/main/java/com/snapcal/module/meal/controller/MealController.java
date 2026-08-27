package com.snapcal.module.meal.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.meal.dto.MealSaveReqDTO;
import com.snapcal.module.meal.dto.MealUpdateReqDTO;
import com.snapcal.module.meal.service.MealService;
import com.snapcal.module.meal.vo.MealVO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/meal")
@RequiredArgsConstructor
public class MealController {

    private final MealService mealService;

    @PostMapping
    public Result<MealVO> save(@Valid @RequestBody MealSaveReqDTO dto) {
        return Result.success(mealService.save(dto));
    }

    @GetMapping("/day")
    public Result<List<MealVO>> day(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return Result.success(mealService.day(date != null ? date : LocalDate.now()));
    }

    /** 最近 N 天餐次 (按天分组) */
    @GetMapping("/range")
    public Result<java.util.Map<String, List<MealVO>>> range(
            @RequestParam(defaultValue = "7") int days) {
        int bounded = Math.min(Math.max(days, 1), 90);
        return Result.success(mealService.range(bounded));
    }

    /** 编辑餐次 (备注/类型/份量) */
    @PutMapping("/{id}")
    public Result<MealVO> update(@PathVariable Long id, @Valid @RequestBody MealUpdateReqDTO dto) {
        return Result.success(mealService.update(id, dto));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        mealService.delete(id);
        return Result.success();
    }
}
