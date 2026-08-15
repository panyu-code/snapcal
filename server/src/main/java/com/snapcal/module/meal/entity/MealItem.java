package com.snapcal.module.meal.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;

@Data
@TableName("sc_meal_item")
public class MealItem implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long mealId;

    private String foodName;

    private Integer weightG;

    private Integer kcal;

    private Double proteinG;

    private Double carbsG;

    private Double fatG;

    /** AI/MANUAL/LIBRARY */
    private String source;
}
