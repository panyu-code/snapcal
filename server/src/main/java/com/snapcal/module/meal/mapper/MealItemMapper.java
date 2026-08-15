package com.snapcal.module.meal.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.snapcal.module.meal.entity.MealItem;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface MealItemMapper extends BaseMapper<MealItem> {
}
