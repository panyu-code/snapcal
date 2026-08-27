package com.snapcal.module.water.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.snapcal.common.result.Result;
import com.snapcal.module.water.dto.WaterAddReqDTO;
import com.snapcal.module.water.entity.WaterLog;
import com.snapcal.module.water.mapper.WaterLogMapper;
import com.snapcal.module.water.vo.WaterTodayVO;
import com.snapcal.security.UserContext;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/water")
@RequiredArgsConstructor
public class WaterController {

    private static final int GOAL_ML = 2000;

    private final WaterLogMapper waterLogMapper;

    /** 今日饮水汇总 */
    @GetMapping("/today")
    public Result<WaterTodayVO> today() {
        Long userId = UserContext.requireUserId();
        WaterTodayVO vo = new WaterTodayVO();
        vo.setDate(LocalDate.now().toString());
        vo.setTotalMl(sumOfDay(userId, LocalDate.now()));
        vo.setGoalMl(GOAL_ML);
        return Result.success(vo);
    }

    /** 饮水 (amountMl 为负时撤销) */
    @PostMapping
    public Result<WaterTodayVO> add(@Valid @RequestBody WaterAddReqDTO dto) {
        Long userId = UserContext.requireUserId();
        WaterLog log = new WaterLog();
        log.setUserId(userId);
        log.setLogDate(LocalDate.now());
        log.setAmountMl(dto.getAmountMl());
        waterLogMapper.insert(log);

        // 撤销后总量不为负
        int total = sumOfDay(userId, LocalDate.now());
        WaterTodayVO vo = new WaterTodayVO();
        vo.setDate(LocalDate.now().toString());
        vo.setTotalMl(Math.max(total, 0));
        vo.setGoalMl(GOAL_ML);
        return Result.success(vo);
    }

    /** 最近 N 天饮水 (趋势用) */
    @GetMapping("/range")
    public Result<List<WaterTodayVO>> range(@RequestParam(defaultValue = "7") int days) {
        Long userId = UserContext.requireUserId();
        int bounded = Math.min(Math.max(days, 1), 90);
        LocalDate today = LocalDate.now();
        List<WaterTodayVO> result = new java.util.ArrayList<>();
        for (LocalDate d = today.minusDays(bounded - 1L); !d.isAfter(today); d = d.plusDays(1)) {
            WaterTodayVO vo = new WaterTodayVO();
            vo.setDate(d.toString());
            vo.setTotalMl(sumOfDay(userId, d));
            vo.setGoalMl(GOAL_ML);
            result.add(vo);
        }
        return Result.success(result);
    }

    private int sumOfDay(Long userId, LocalDate date) {
        Integer sum = waterLogMapper.selectList(new LambdaQueryWrapper<WaterLog>()
                        .eq(WaterLog::getUserId, userId)
                        .eq(WaterLog::getLogDate, date))
                .stream().mapToInt(WaterLog::getAmountMl).sum();
        return sum == null ? 0 : sum;
    }
}
