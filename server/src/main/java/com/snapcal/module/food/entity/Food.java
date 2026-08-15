package com.snapcal.module.food.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;

@Data
@TableName("sc_food")
public class Food implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String name;

    /** 食物专属 emoji (新增食物时 INSERT 带上即可, 无需改代码) */
    private String emoji;

    /** 食物高清图片 URL (RustFS) */
    private String imageUrl;

    private String category;

    private Integer kcalPer100g;

    private Double proteinPer100g;

    private Double carbsPer100g;

    private Double fatPer100g;
}
