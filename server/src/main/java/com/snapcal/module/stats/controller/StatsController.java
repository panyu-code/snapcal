package com.snapcal.module.stats.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.stats.service.StatsService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/stats")
@RequiredArgsConstructor
public class StatsController {

    private final StatsService statsService;

    /** 最近 N 天每日摄入 */
    @GetMapping("/daily")
    public Result<List<Map<String, Object>>> daily(@RequestParam(defaultValue = "7") int days) {
        return Result.success(statsService.dailyIntake(days));
    }
}
