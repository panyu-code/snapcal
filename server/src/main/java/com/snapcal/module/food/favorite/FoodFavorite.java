package com.snapcal.module.food.favorite;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@TableName("sc_food_favorite")
public class FoodFavorite implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    private Long foodId;

    private LocalDateTime createTime;
}
