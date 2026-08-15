package com.snapcal.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

/** 开发模式登录 (模拟器调试用, 生产关闭) */
@Data
public class DevLoginReqDTO implements Serializable {

    @NotBlank(message = "用户名不能为空")
    @Pattern(regexp = "^[a-zA-Z0-9_]{2,30}$", message = "用户名仅限字母数字下划线")
    @Size(max = 30)
    private String username;
}
