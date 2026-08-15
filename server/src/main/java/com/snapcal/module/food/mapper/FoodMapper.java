package com.snapcal.module.food.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.snapcal.module.food.entity.Food;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface FoodMapper extends BaseMapper<Food> {
}
