package com.snapcal.module.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@TableName("sc_user")
public class User implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** Apple 用户唯一标识 (sub) / dev_xxx 开发账号 */
    private String appleUserId;

    private String nickname;

    private String avatar;

    /** 1男 2女 */
    private Integer gender;

    private Integer birthYear;

    private Double heightCm;

    /** LOSE / KEEP / GAIN */
    private String targetType;

    private Double goalWeightKg;

    /** 每日热量目标 kcal */
    private Integer dailyKcalTarget;

    private LocalDateTime proExpireTime;

    @TableField(fill = com.baomidou.mybatisplus.annotation.FieldFill.INSERT)
    private LocalDateTime createTime;
}
