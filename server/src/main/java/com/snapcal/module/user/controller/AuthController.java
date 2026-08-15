package com.snapcal.module.user.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.user.dto.AppleLoginReqDTO;
import com.snapcal.module.user.dto.DevLoginReqDTO;
import com.snapcal.module.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserService userService;

    /** Apple 登录 (Sign in with Apple identityToken) */
    @PostMapping("/apple")
    public Result<Map<String, Object>> apple(@Valid @RequestBody AppleLoginReqDTO dto) {
        return Result.success(userService.appleLogin(dto));
    }

    /** 开发模式登录 (模拟器调试, 生产关闭) */
    @PostMapping("/dev-login")
    public Result<Map<String, Object>> devLogin(@Valid @RequestBody DevLoginReqDTO dto) {
        return Result.success(userService.devLogin(dto));
    }
}
