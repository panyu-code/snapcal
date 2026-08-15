package com.snapcal.module.meal.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@TableName("sc_meal")
public class Meal implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** BREAKFAST/LUNCH/DINNER/SNACK */
    private String mealType;

    private String photoUrl;

    private Integer totalKcal;

    private Double proteinG;

    private Double carbsG;

    private Double fatG;

    private Double aiConfidence;

    private LocalDateTime eatTime;

    private LocalDateTime createTime;
}
