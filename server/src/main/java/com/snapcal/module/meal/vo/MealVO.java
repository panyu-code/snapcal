package com.snapcal.module.meal.vo;

import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class MealVO implements Serializable {

    private Long id;
    private String mealType;
    private String photoUrl;
    private Integer totalKcal;
    private Double proteinG;
    private Double carbsG;
    private Double fatG;
    private LocalDateTime eatTime;
    private String note;
    private List<Item> items;

    @Data
    public static class Item implements Serializable {
        private String foodName;
        private Integer weightG;
        private Integer kcal;
        private Double proteinG;
        private Double carbsG;
        private Double fatG;
        private String source;
    }
}
