package com.snapcal.module.food.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.snapcal.module.food.favorite.FoodFavorite;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface FoodFavoriteMapper extends BaseMapper<FoodFavorite> {
}
