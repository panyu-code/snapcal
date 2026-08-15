package com.snapcal.module.user.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

@Data
public class ProfileUpdateReqDTO implements Serializable {

    @Size(max = 50, message = "昵称过长")
    private String nickname;

    @Min(value = 1, message = "性别不合法")
    @Max(value = 2, message = "性别不合法")
    private Integer gender;

    @Min(value = 1920)
    @Max(value = 2020)
    private Integer birthYear;

    @DecimalMin(value = "80", message = "身高范围 80-250cm")
    @DecimalMax(value = "250", message = "身高范围 80-250cm")
    private Double heightCm;

    @DecimalMin(value = "25", message = "体重范围 25-300kg")
    @DecimalMax(value = "300", message = "体重范围 25-300kg")
    private Double currentWeightKg;

    @DecimalMin(value = "25")
    @DecimalMax(value = "300")
    private Double goalWeightKg;

    @Pattern(regexp = "^(LOSE|KEEP|GAIN)$", message = "目标类型不合法")
    private String targetType;

    /** 慢/中/快 速 */
    @Pattern(regexp = "^(SLOW|MID|FAST)$", message = "速度不合法")
    private String pace;

    /** 活动系数 1.2 久坐 ~ 1.725 高运动量 */
    @DecimalMin(value = "1.0")
    @DecimalMax(value = "2.0")
    private Double activityFactor;
}
