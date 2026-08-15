package com.snapcal.security;

import cn.hutool.jwt.JWT;
import cn.hutool.jwt.JWTUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * 服务端 JWT 签发与校验 (HS256)
 */
@Component
public class JwtUtil {

    @Value("${snapcal.jwt.secret}")
    private String secret;

    @Value("${snapcal.jwt.expire-days:30}")
    private long expireDays;

    public String issue(Long userId) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("uid", userId);
        payload.put("exp", System.currentTimeMillis() / 1000 + expireDays * 86400);
        return JWTUtil.createToken(payload, secret.getBytes());
    }

    /** 校验并返回 userId, 失败返回 null */
    public Long verify(String token) {
        try {
            if (!JWTUtil.verify(token, secret.getBytes())) {
                return null;
            }
            JWT jwt = JWT.of(token);
            Long exp = Long.parseLong(String.valueOf(jwt.getPayload("exp")));
            if (exp < System.currentTimeMillis() / 1000) {
                return null;
            }
            return Long.parseLong(String.valueOf(jwt.getPayload("uid")));
        } catch (Exception e) {
            return null;
        }
    }
}
