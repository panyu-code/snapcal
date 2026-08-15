package com.snapcal.module.user.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.snapcal.common.exception.BizException;
import com.snapcal.common.result.Result;
import com.snapcal.module.user.entity.Weight;
import com.snapcal.module.user.mapper.WeightMapper;
import com.snapcal.security.UserContext;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/weight")
@RequiredArgsConstructor
public class WeightController {

    private final WeightMapper weightMapper;

    /** 记录体重 (同日覆盖) */
    @PostMapping
    public Result<Void> record(@RequestBody WeightReq req) {
        Long userId = UserContext.requireUserId();
        LocalDate date = req.getRecordDate() != null ? req.getRecordDate() : LocalDate.now();

        Weight exist = weightMapper.selectOne(new LambdaQueryWrapper<Weight>()
                .eq(Weight::getUserId, userId)
                .eq(Weight::getRecordDate, date)
                .last("LIMIT 1"));
        if (exist == null) {
            Weight w = new Weight();
            w.setUserId(userId);
            w.setRecordDate(date);
            w.setWeightKg(req.getWeightKg());
            weightMapper.insert(w);
        } else {
            exist.setWeightKg(req.getWeightKg());
            weightMapper.updateById(exist);
        }
        return Result.success();
    }

    /** 最近 N 天体重序列 */
    @GetMapping("/list")
    public Result<List<Weight>> list(@RequestParam(defaultValue = "30") int days) {
        Long userId = UserContext.requireUserId();
        int bounded = Math.min(Math.max(days, 1), 365);
        return Result.success(weightMapper.selectList(new LambdaQueryWrapper<Weight>()
                .eq(Weight::getUserId, userId)
                .ge(Weight::getRecordDate, LocalDate.now().minusDays(bounded - 1L))
                .orderByAsc(Weight::getRecordDate)));
    }

    @Data
    public static class WeightReq {
        @NotNull(message = "体重不能为空")
        @DecimalMin(value = "25", message = "体重范围 25-300kg")
        @DecimalMax(value = "300", message = "体重范围 25-300kg")
        private Double weightKg;

        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        private LocalDate recordDate;
    }
}
