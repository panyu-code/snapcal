package com.snapcal.security;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.snapcal.common.exception.BizException;
import com.snapcal.common.result.ResultCode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.RSAPublicKeySpec;
import java.time.Duration;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Apple identityToken 校验器
 * 1. 拉取 Apple 公钥 (JWKS, 缓存 24h)
 * 2. RS256 验签
 * 3. 校验 iss / aud / exp
 * 返回苹果用户唯一标识 sub
 */
@Slf4j
@Component
public class AppleTokenVerifier {

    private static final String JWKS_URL = "https://appleid.apple.com/auth/keys";
    private static final String ISSUER = "https://appleid.apple.com";

    @Value("${snapcal.apple.audience}")
    private String audience;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10)).build();

    /** kid -> PublicKey 缓存 */
    private volatile Map<String, PublicKey> cachedKeys = new ConcurrentHashMap<>();
    private volatile long keysFetchedAt = 0;

    /** 验证 identityToken, 返回 Apple 用户唯一 sub */
    public String verify(String identityToken) {
        try {
            String[] parts = identityToken.split("\\.");
            if (parts.length != 3) {
                throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
            }
            var decoder = Base64.getUrlDecoder();

            JsonNode header = objectMapper.readTree(new String(decoder.decode(parts[0]), StandardCharsets.UTF_8));
            if (!"RS256".equals(header.path("alg").asText())) {
                throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
            }
            String kid = header.path("kid").asText();

            PublicKey publicKey = getKey(kid);
            if (publicKey == null) {
                throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
            }

            // RS256 验签: 对 header.payload 做 SHA256withRSA
            Signature signature = Signature.getInstance("SHA256withRSA");
            signature.initVerify(publicKey);
            signature.update((parts[0] + "." + parts[1]).getBytes(StandardCharsets.UTF_8));
            if (!signature.verify(decoder.decode(parts[2]))) {
                throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
            }

            JsonNode payload = objectMapper.readTree(new String(decoder.decode(parts[1]), StandardCharsets.UTF_8));
            if (!ISSUER.equals(payload.path("iss").asText())) {
                throw new BizException("Apple 令牌签发方不符");
            }
            if (!audience.equals(payload.path("aud").asText())) {
                throw new BizException("Apple 令牌与当前 App 不匹配");
            }
            if (payload.path("exp").asLong() < System.currentTimeMillis() / 1000) {
                throw new BizException("Apple 令牌已过期");
            }
            String sub = payload.path("sub").asText();
            if (sub.isEmpty()) {
                throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
            }
            return sub;
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Apple 令牌验证异常: {}", e.getMessage());
            throw new BizException(ResultCode.APPLE_TOKEN_INVALID);
        }
    }

    private PublicKey getKey(String kid) throws Exception {
        Map<String, PublicKey> keys = cachedKeys;
        long age = System.currentTimeMillis() - keysFetchedAt;
        if (keys.isEmpty() || age > Duration.ofHours(24).toMillis()) {
            keys = fetchJwks();
        }
        return keys.get(kid);
    }

    private synchronized Map<String, PublicKey> fetchJwks() throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(JWKS_URL)).GET().build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new BizException("获取 Apple 公钥失败: HTTP " + response.statusCode());
        }
        Map<String, PublicKey> keys = new HashMap<>();
        JsonNode jwks = objectMapper.readTree(response.body());
        for (JsonNode node : jwks.path("keys")) {
            try {
                BigInteger modulus = new BigInteger(1, Base64.getUrlDecoder().decode(node.path("n").asText()));
                BigInteger exponent = new BigInteger(1, Base64.getUrlDecoder().decode(node.path("e").asText()));
                PublicKey key = KeyFactory.getInstance("RSA")
                        .generatePublic(new RSAPublicKeySpec(modulus, exponent));
                keys.put(node.path("kid").asText(), key);
            } catch (Exception ignored) {
            }
        }
        cachedKeys = keys;
        keysFetchedAt = System.currentTimeMillis();
        log.info("已拉取 Apple 公钥 {} 把", keys.size());
        return keys;
    }
}
