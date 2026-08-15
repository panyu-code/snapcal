package com.snapcal.module.meal.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class MealSaveReqDTO implements Serializable {

    @NotBlank(message = "餐次类型不能为空")
    @Pattern(regexp = "^(BREAKFAST|LUNCH|DINNER|SNACK)$", message = "餐次类型不合法")
    private String mealType;

    private String photoUrl;

    private LocalDateTime eatTime;

    @NotEmpty(message = "食物明细不能为空")
    private List<Item> items;

    @Data
    public static class Item implements Serializable {
        @NotBlank(message = "食物名不能为空")
        private String foodName;

        @NotNull(message = "克重不能为空")
        private Integer weightG;

        private Integer kcal;

        private Double proteinG;

        private Double carbsG;

        private Double fatG;

        private String source;
    }
}
