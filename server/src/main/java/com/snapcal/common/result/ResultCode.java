package com.snapcal.common.result;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum ResultCode {

    SUCCESS(200, "操作成功"),
    FAIL(500, "操作失败"),

    BAD_REQUEST(400, "请求参数错误"),
    UNAUTHORIZED(401, "未登录或登录已过期"),
    FORBIDDEN(403, "无权限访问"),
    NOT_FOUND(404, "资源不存在"),

    PARAM_VALIDATE_FAILED(10001, "参数校验失败"),
    APPLE_TOKEN_INVALID(10002, "Apple 令牌校验失败"),
    DEV_MODE_OFF(10003, "开发登录未开启"),
    USER_NOT_FOUND(10004, "用户不存在"),
    USERNAME_EXISTS(10005, "用户名已被使用"),
    EMAIL_EXISTS(10006, "邮箱已被注册"),
    INVALID_CREDENTIALS(10007, "用户名或密码错误"),
    VERIFICATION_CODE_INVALID(10008, "验证码错误"),
    VERIFICATION_CODE_EXPIRED(10009, "验证码已过期，请重新获取"),
    VERIFICATION_CODE_TOO_FREQUENT(10010, "验证码发送过于频繁，请稍后再试"),
    VERIFICATION_CODE_ATTEMPTS_EXCEEDED(10011, "验证码错误次数过多，请重新获取"),
    EMAIL_NOT_FOUND(10012, "该邮箱尚未注册"),
    MAIL_SEND_FAILED(10013, "验证码邮件发送失败，请稍后重试"),

    SYSTEM_ERROR(50000, "系统异常");

    private final Integer code;
    private final String message;
}
