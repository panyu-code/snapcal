package com.snapcal.module.meal.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.meal.dto.MealSaveReqDTO;
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

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        mealService.delete(id);
        return Result.success();
    }
}
