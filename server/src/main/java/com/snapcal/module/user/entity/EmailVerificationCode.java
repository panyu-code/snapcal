package com.snapcal.module.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@TableName("sc_email_verification_code")
public class EmailVerificationCode implements Serializable {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String email;
    private String purpose;
    private String codeHash;
    private Integer failedAttempts;
    private LocalDateTime expiresAt;
    private LocalDateTime sentAt;
    private LocalDateTime consumedAt;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
