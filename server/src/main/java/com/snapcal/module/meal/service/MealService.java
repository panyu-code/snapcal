package com.snapcal.module.meal.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.snapcal.common.exception.BizException;
import com.snapcal.module.meal.dto.MealSaveReqDTO;
import com.snapcal.module.meal.dto.MealUpdateReqDTO;
import com.snapcal.module.meal.entity.Meal;
import com.snapcal.module.meal.entity.MealItem;
import com.snapcal.module.meal.mapper.MealItemMapper;
import com.snapcal.module.meal.mapper.MealMapper;
import com.snapcal.module.meal.vo.MealVO;
import com.snapcal.security.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class MealService {

    private final MealMapper mealMapper;
    private final MealItemMapper itemMapper;

    /** 保存餐次 (含明细), 自动汇总营养 */
    @Transactional
    public MealVO save(MealSaveReqDTO dto) {
        Long userId = UserContext.requireUserId();

        Meal meal = new Meal();
        meal.setUserId(userId);
        meal.setMealType(dto.getMealType());
        meal.setPhotoUrl(dto.getPhotoUrl());
        meal.setEatTime(dto.getEatTime() != null ? dto.getEatTime() : LocalDateTime.now());
        meal.setNote(dto.getNote());

        int totalKcal = 0;
        double totalProtein = 0, totalCarbs = 0, totalFat = 0;
        for (MealSaveReqDTO.Item i : dto.getItems()) {
            totalKcal += i.getKcal() != null ? i.getKcal() : 0;
            totalProtein += i.getProteinG() != null ? i.getProteinG() : 0;
            totalCarbs += i.getCarbsG() != null ? i.getCarbsG() : 0;
            totalFat += i.getFatG() != null ? i.getFatG() : 0;
        }
        meal.setTotalKcal(totalKcal);
        meal.setProteinG(totalProtein);
        meal.setCarbsG(totalCarbs);
        meal.setFatG(totalFat);
        mealMapper.insert(meal);

        List<MealVO.Item> items = new ArrayList<>();
        for (MealSaveReqDTO.Item i : dto.getItems()) {
            MealItem mi = new MealItem();
            mi.setMealId(meal.getId());
            mi.setFoodName(i.getFoodName());
            mi.setWeightG(i.getWeightG());
            mi.setKcal(i.getKcal() != null ? i.getKcal() : 0);
            mi.setProteinG(i.getProteinG() != null ? i.getProteinG() : 0);
            mi.setCarbsG(i.getCarbsG() != null ? i.getCarbsG() : 0);
            mi.setFatG(i.getFatG() != null ? i.getFatG() : 0);
            mi.setSource(i.getSource() != null ? i.getSource() : "AI");
            itemMapper.insert(mi);

            MealVO.Item voItem = new MealVO.Item();
            voItem.setFoodName(mi.getFoodName());
            voItem.setWeightG(mi.getWeightG());
            voItem.setKcal(mi.getKcal());
            voItem.setProteinG(mi.getProteinG());
            voItem.setCarbsG(mi.getCarbsG());
            voItem.setFatG(mi.getFatG());
            voItem.setSource(mi.getSource());
            items.add(voItem);
        }

        log.info("餐次保存: user={} type={} kcal={} items={}", userId, meal.getMealType(), totalKcal, items.size());
        return toVO(meal, items);
    }

    /** 某日全部餐次 */
    public List<MealVO> day(LocalDate date) {
        Long userId = UserContext.requireUserId();
        LocalDateTime start = date.atStartOfDay();
        LocalDateTime end = date.plusDays(1).atStartOfDay();
        return queryBetween(userId, start, end);
    }

    /** 最近 N 天餐次, 按日期字符串(MM-dd)分组 */
    public Map<String, List<MealVO>> range(int days) {
        Long userId = UserContext.requireUserId();
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.minusDays(days - 1L).atStartOfDay();
        LocalDateTime end = today.plusDays(1).atStartOfDay();

        Map<String, List<MealVO>> grouped = new java.util.LinkedHashMap<>();
        for (LocalDate d = today.minusDays(days - 1L); !d.isAfter(today); d = d.plusDays(1)) {
            grouped.put(d.toString(), new ArrayList<>());
        }
        for (MealVO vo : queryBetween(userId, start, end)) {
            String key = vo.getEatTime() != null ? vo.getEatTime().toLocalDate().toString() : today.toString();
            grouped.computeIfAbsent(key, k -> new ArrayList<>()).add(vo);
        }
        return grouped;
    }

    private List<MealVO> queryBetween(Long userId, LocalDateTime start, LocalDateTime end) {
        List<Meal> meals = mealMapper.selectList(new LambdaQueryWrapper<Meal>()
                .eq(Meal::getUserId, userId)
                .ge(Meal::getEatTime, start)
                .lt(Meal::getEatTime, end)
                .orderByDesc(Meal::getEatTime));

        List<MealVO> result = new ArrayList<>();
        for (Meal meal : meals) {
            List<MealItem> items = itemMapper.selectList(new LambdaQueryWrapper<MealItem>()
                    .eq(MealItem::getMealId, meal.getId()));
            List<MealVO.Item> voItems = items.stream().map(mi -> {
                MealVO.Item i = new MealVO.Item();
                i.setFoodName(mi.getFoodName());
                i.setWeightG(mi.getWeightG());
                i.setKcal(mi.getKcal());
                i.setProteinG(mi.getProteinG());
                i.setCarbsG(mi.getCarbsG());
                i.setFatG(mi.getFatG());
                i.setSource(mi.getSource());
                return i;
            }).toList();
            result.add(toVO(meal, voItems));
        }
        return result;
    }


    /** 编辑餐次 (备注/类型/明细份量), 重建明细并重新汇总 */
    @Transactional
    public MealVO update(Long mealId, MealUpdateReqDTO dto) {
        Long userId = UserContext.requireUserId();
        Meal meal = mealMapper.selectById(mealId);
        if (meal == null || !meal.getUserId().equals(userId)) {
            throw new BizException("餐次不存在");
        }
        meal.setMealType(dto.getMealType());
        meal.setNote(dto.getNote());
        applyItems(meal, dto.getItems());
        mealMapper.updateById(meal);

        List<MealVO.Item> voItems = itemMapper.selectList(
                        new LambdaQueryWrapper<MealItem>().eq(MealItem::getMealId, mealId))
                .stream().map(mi -> {
                    MealVO.Item i = new MealVO.Item();
                    i.setFoodName(mi.getFoodName());
                    i.setWeightG(mi.getWeightG());
                    i.setKcal(mi.getKcal());
                    i.setProteinG(mi.getProteinG());
                    i.setCarbsG(mi.getCarbsG());
                    i.setFatG(mi.getFatG());
                    i.setSource(mi.getSource());
                    return i;
                }).toList();
        log.info("餐次编辑: user={} mealId={} kcal={}", userId, mealId, meal.getTotalKcal());
        return toVO(meal, voItems);
    }

    /** 清空旧明细, 按新明细写入并汇总营养到 meal */
    private void applyItems(Meal meal, List<MealUpdateReqDTO.Item> items) {
        itemMapper.delete(new LambdaQueryWrapper<MealItem>().eq(MealItem::getMealId, meal.getId()));
        int totalKcal = 0;
        double totalProtein = 0, totalCarbs = 0, totalFat = 0;
        for (MealUpdateReqDTO.Item i : items) {
            MealItem mi = new MealItem();
            mi.setMealId(meal.getId());
            mi.setFoodName(i.getFoodName());
            mi.setWeightG(i.getWeightG());
            mi.setKcal(i.getKcal() != null ? i.getKcal() : 0);
            mi.setProteinG(i.getProteinG() != null ? i.getProteinG() : 0);
            mi.setCarbsG(i.getCarbsG() != null ? i.getCarbsG() : 0);
            mi.setFatG(i.getFatG() != null ? i.getFatG() : 0);
            mi.setSource(i.getSource() != null ? i.getSource() : "AI");
            itemMapper.insert(mi);
            totalKcal += mi.getKcal();
            totalProtein += mi.getProteinG();
            totalCarbs += mi.getCarbsG();
            totalFat += mi.getFatG();
        }
        meal.setTotalKcal(totalKcal);
        meal.setProteinG(totalProtein);
        meal.setCarbsG(totalCarbs);
        meal.setFatG(totalFat);
    }

    /** 删除餐次 */
    @Transactional
    public void delete(Long mealId) {
        Long userId = UserContext.requireUserId();
        Meal meal = mealMapper.selectById(mealId);
        if (meal == null || !meal.getUserId().equals(userId)) {
            throw new BizException("餐次不存在");
        }
        itemMapper.delete(new LambdaQueryWrapper<MealItem>().eq(MealItem::getMealId, mealId));
        mealMapper.deleteById(mealId);
    }

    private MealVO toVO(Meal meal, List<MealVO.Item> items) {
        MealVO vo = new MealVO();
        vo.setId(meal.getId());
        vo.setMealType(meal.getMealType());
        vo.setPhotoUrl(meal.getPhotoUrl());
        vo.setTotalKcal(meal.getTotalKcal());
        vo.setProteinG(meal.getProteinG());
        vo.setCarbsG(meal.getCarbsG());
        vo.setFatG(meal.getFatG());
        vo.setEatTime(meal.getEatTime());
        vo.setNote(meal.getNote());
        vo.setItems(items);
        return vo;
    }
}
