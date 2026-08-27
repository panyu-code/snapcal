package com.snapcal.module.water.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.io.Serializable;

@Data
public class WaterAddReqDTO implements Serializable {

    /** 毫升, 正数饮水 / 负数撤销 */
    @NotNull(message = "水量不能为空")
    @Min(value = -2000, message = "单次撤销不能超过 2000ml")
    @Max(value = 2000, message = "单次饮水不能超过 2000ml")
    private Integer amountMl;
}
