package com.snapcal.module.user.controller;

import com.snapcal.common.result.Result;
import com.snapcal.module.user.dto.AppleLoginReqDTO;
import com.snapcal.module.user.dto.DevLoginReqDTO;
import com.snapcal.module.user.dto.PasswordLoginReqDTO;
import com.snapcal.module.user.dto.PasswordRegisterReqDTO;
import com.snapcal.module.user.dto.ResetPasswordReqDTO;
import com.snapcal.module.user.dto.SendEmailCodeReqDTO;
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

    /** 发送邮箱验证码 (REGISTER / RESET_PASSWORD) */
    @PostMapping("/email-code")
    public Result<Void> emailCode(@Valid @RequestBody SendEmailCodeReqDTO dto) {
        userService.sendEmailCode(dto);
        return Result.success();
    }

    /** 用户名 + 密码 + 邮箱 + 验证码注册 */
    @PostMapping("/register")
    public Result<Map<String, Object>> register(@Valid @RequestBody PasswordRegisterReqDTO dto) {
        return Result.success(userService.register(dto));
    }

    /** 用户名或邮箱 + 密码登录 */
    @PostMapping("/login")
    public Result<Map<String, Object>> login(@Valid @RequestBody PasswordLoginReqDTO dto) {
        return Result.success(userService.passwordLogin(dto));
    }

    /** 邮箱验证码重置密码 */
    @PostMapping("/password/reset")
    public Result<Void> resetPassword(@Valid @RequestBody ResetPasswordReqDTO dto) {
        userService.resetPassword(dto);
        return Result.success();
    }
}
