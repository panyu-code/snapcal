package com.snapcal.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

@Data
public class PasswordLoginReqDTO implements Serializable {

    @NotBlank(message = "用户名不能为空")
    @Size(max = 30, message = "用户名长度不能超过30位")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Size(max = 72, message = "密码长度不能超过72位")
    private String password;
}
