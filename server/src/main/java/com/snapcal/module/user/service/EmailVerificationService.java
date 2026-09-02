package com.snapcal.module.user.service;

import com.snapcal.common.exception.BizException;
import com.snapcal.common.result.ResultCode;
import com.snapcal.module.user.entity.EmailVerificationCode;
import com.snapcal.module.user.mapper.EmailVerificationCodeMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Locale;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailVerificationService {

    public static final String REGISTER = "REGISTER";
    public static final String RESET_PASSWORD = "RESET_PASSWORD";
    private static final int MAX_FAILED_ATTEMPTS = 5;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final EmailVerificationCodeMapper codeMapper;
    private final JavaMailSender mailSender;
    private final PasswordEncoder passwordEncoder;

    @Value("${snapcal.auth.mail-from:}")
    private String mailFrom;

    @Value("${snapcal.auth.code-expire-minutes:10}")
    private long expireMinutes;

    @Transactional
    public void send(String email, String purpose) {
        String normalizedEmail = normalizeEmail(email);
        LocalDateTime now = LocalDateTime.now();
        EmailVerificationCode record = codeMapper.selectForUpdate(normalizedEmail, purpose);
        if (record != null && record.getSentAt() != null
                && record.getSentAt().plusSeconds(60).isAfter(now)) {
            throw new BizException(ResultCode.VERIFICATION_CODE_TOO_FREQUENT);
        }

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        if (record == null) {
            record = new EmailVerificationCode();
            record.setEmail(normalizedEmail);
            record.setPurpose(purpose);
            record.setCreateTime(now);
        }
        record.setCodeHash(passwordEncoder.encode(code));
        record.setFailedAttempts(0);
        record.setExpiresAt(now.plusMinutes(expireMinutes));
        record.setSentAt(now);
        record.setConsumedAt(null);
        record.setUpdateTime(now);

        try {
            sendMail(normalizedEmail, purpose, code);
            if (record.getId() == null) {
                codeMapper.insert(record);
            } else {
                codeMapper.updateById(record);
            }
        } catch (MailException e) {
            log.error("验证码邮件发送失败: email={}, purpose={}", normalizedEmail, purpose, e);
            throw new BizException(ResultCode.MAIL_SEND_FAILED);
        }
    }

    /**
     * 单独事务确保验证码错误次数即使抛出业务异常也会落库；验证成功立即标记消费。
     */
    @Transactional(noRollbackFor = BizException.class)
    public void verifyAndConsume(String email, String purpose, String code) {
        String normalizedEmail = normalizeEmail(email);
        LocalDateTime now = LocalDateTime.now();
        EmailVerificationCode record = codeMapper.selectForUpdate(normalizedEmail, purpose);
        if (record == null || record.getConsumedAt() != null) {
            throw new BizException(ResultCode.VERIFICATION_CODE_INVALID);
        }
        if (record.getExpiresAt() == null || !record.getExpiresAt().isAfter(now)) {
            throw new BizException(ResultCode.VERIFICATION_CODE_EXPIRED);
        }
        int failedAttempts = record.getFailedAttempts() == null ? 0 : record.getFailedAttempts();
        if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
            throw new BizException(ResultCode.VERIFICATION_CODE_ATTEMPTS_EXCEEDED);
        }
        if (!passwordEncoder.matches(code, record.getCodeHash())) {
            record.setFailedAttempts(failedAttempts + 1);
            record.setUpdateTime(now);
            codeMapper.updateById(record);
            if (record.getFailedAttempts() >= MAX_FAILED_ATTEMPTS) {
                throw new BizException(ResultCode.VERIFICATION_CODE_ATTEMPTS_EXCEEDED);
            }
            throw new BizException(ResultCode.VERIFICATION_CODE_INVALID);
        }
        record.setConsumedAt(now);
        record.setUpdateTime(now);
        codeMapper.updateById(record);
    }

    private void sendMail(String email, String purpose, String code) {
        if (!StringUtils.hasText(mailFrom)) {
            throw new BizException(ResultCode.MAIL_SEND_FAILED);
        }
        long minutes = Math.max(1, expireMinutes);
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(mailFrom);
        message.setTo(email);
        message.setSubject(REGISTER.equals(purpose) ? "SnapCal 注册验证码" : "SnapCal 重置密码验证码");
        message.setText("您的 SnapCal 验证码是：" + code + "\n\n验证码 " + minutes
                + " 分钟内有效，请勿泄露给他人。如非本人操作，请忽略本邮件。");
        mailSender.send(message);
    }

    public static String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
