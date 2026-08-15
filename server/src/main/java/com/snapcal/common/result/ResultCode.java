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

    SYSTEM_ERROR(50000, "系统异常");

    private final Integer code;
    private final String message;
}
