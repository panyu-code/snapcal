package com.snapcal.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

@Data
public class ResetPasswordReqDTO implements Serializable {

    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    @Size(max = 254, message = "邮箱长度不能超过254位")
    private String email;

    @NotBlank(message = "验证码不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "验证码须为6位数字")
    private String code;

    @NotBlank(message = "新密码不能为空")
    @Size(min = 8, max = 72, message = "新密码长度须为8-72位")
    private String newPassword;
}
