package com.snapcal.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.io.Serializable;

@Data
public class AppleLoginReqDTO implements Serializable {

    @NotBlank(message = "identityToken 不能为空")
    @Size(max = 4096)
    private String identityToken;

    /** 首次授权时可拿到昵称 (仅首次, 可空) */
    @Size(max = 50)
    private String nickname;
}
