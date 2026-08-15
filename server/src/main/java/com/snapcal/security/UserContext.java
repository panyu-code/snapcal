package com.snapcal.security;

/** 请求级用户上下文 (拦截器写入, Controller/Service 读取) */
public class UserContext {

    private static final ThreadLocal<Long> HOLDER = new ThreadLocal<>();

    public static void set(Long userId) {
        HOLDER.set(userId);
    }

    public static Long getUserId() {
        return HOLDER.get();
    }

    public static Long requireUserId() {
        Long userId = HOLDER.get();
        if (userId == null) {
            throw new com.snapcal.common.exception.BizException(
                    com.snapcal.common.result.ResultCode.UNAUTHORIZED);
        }
        return userId;
    }

    public static void clear() {
        HOLDER.remove();
    }
}
