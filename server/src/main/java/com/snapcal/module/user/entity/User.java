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

    /** Apple 用户唯一标识 (sub) / dev_xxx 开发账号；账号密码用户可为空 */
    private String appleUserId;

    /** 正式账号用户名，统一以小写存储 */
    private String username;

    /** 正式账号邮箱，统一以小写存储 */
    private String email;

    /** BCrypt 密码摘要，Apple/dev 用户可为空 */
    private String passwordHash;

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

    /** 最近登录时间 */
    private LocalDateTime lastLoginTime;
}
