package com.snapcal.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

@Data
public class SendEmailCodeReqDTO implements Serializable {

    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    @Size(max = 254, message = "邮箱长度不能超过254位")
    private String email;

    @NotBlank(message = "验证码用途不能为空")
    @Pattern(regexp = "^(REGISTER|RESET_PASSWORD)$", message = "验证码用途仅支持 REGISTER 或 RESET_PASSWORD")
    private String purpose;
}
