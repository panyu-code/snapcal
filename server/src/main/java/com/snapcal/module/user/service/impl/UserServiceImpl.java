package com.snapcal.module.user.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.snapcal.common.exception.BizException;
import com.snapcal.common.result.ResultCode;
import com.snapcal.module.user.dto.AppleLoginReqDTO;
import com.snapcal.module.user.dto.DevLoginReqDTO;
import com.snapcal.module.user.dto.PasswordLoginReqDTO;
import com.snapcal.module.user.dto.PasswordRegisterReqDTO;
import com.snapcal.module.user.dto.ProfileUpdateReqDTO;
import com.snapcal.module.user.dto.ResetPasswordReqDTO;
import com.snapcal.module.user.dto.SendEmailCodeReqDTO;
import com.snapcal.module.user.entity.User;
import com.snapcal.module.user.service.EmailVerificationService;
import com.snapcal.module.user.entity.Weight;
import com.snapcal.module.user.mapper.UserMapper;
import com.snapcal.config.oss.OssService;
import org.springframework.web.multipart.MultipartFile;
import java.io.ByteArrayInputStream;
import com.snapcal.module.user.mapper.WeightMapper;
import com.snapcal.module.user.service.UserService;
import com.snapcal.module.user.vo.UserVO;
import com.snapcal.security.AppleTokenVerifier;
import com.snapcal.security.JwtUtil;
import com.snapcal.security.UserContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserMapper userMapper;
    private final WeightMapper weightMapper;
    private final OssService ossService;
    private final AppleTokenVerifier appleTokenVerifier;
    private final JwtUtil jwtUtil;
    private final PasswordEncoder passwordEncoder;
    private final EmailVerificationService emailVerificationService;

    @Value("${snapcal.dev-mode:true}")
    private boolean devMode;

    @Override
    @Transactional
    public Map<String, Object> appleLogin(AppleLoginReqDTO dto) {
        String sub = appleTokenVerifier.verify(dto.getIdentityToken());
        User user = findOrRegister("apple_" + sub, StringUtils.hasText(dto.getNickname()) ? dto.getNickname() : "用户");
        return loginResult(user);
    }

    @Override
    @Transactional
    public Map<String, Object> devLogin(DevLoginReqDTO dto) {
        if (!devMode) {
            throw new BizException(ResultCode.DEV_MODE_OFF);
        }
        User user = findOrRegister("dev_" + dto.getUsername(), dto.getUsername());
        return loginResult(user);
    }

    @Override
    public UserVO me() {
        User user = requireUser();
        return UserVO.of(user, latestWeight(user.getId()));
    }

    @Override
    @Transactional
    public UserVO updateProfile(ProfileUpdateReqDTO dto) {
        User user = requireUser();

        if (StringUtils.hasText(dto.getNickname())) {
            user.setNickname(dto.getNickname());
        }
        if (dto.getGender() != null) user.setGender(dto.getGender());
        if (dto.getBirthYear() != null) user.setBirthYear(dto.getBirthYear());
        if (dto.getHeightCm() != null) user.setHeightCm(dto.getHeightCm());
        if (dto.getGoalWeightKg() != null) user.setGoalWeightKg(dto.getGoalWeightKg());
        if (StringUtils.hasText(dto.getTargetType())) user.setTargetType(dto.getTargetType());

        // 记录当日体重 (同日覆盖)
        if (dto.getCurrentWeightKg() != null) {
            LocalDate today = LocalDate.now();
            Weight weight = weightMapper.selectOne(new LambdaQueryWrapper<Weight>()
                    .eq(Weight::getUserId, user.getId())
                    .eq(Weight::getRecordDate, today)
                    .last("LIMIT 1"));
            if (weight == null) {
                weight = new Weight();
                weight.setUserId(user.getId());
                weight.setRecordDate(today);
                weight.setWeightKg(dto.getCurrentWeightKg());
                weightMapper.insert(weight);
            } else {
                weight.setWeightKg(dto.getCurrentWeightKg());
                weightMapper.updateById(weight);
            }
        }

        // 资料齐全则重算每日热量目标 (Mifflin-St Jeor)
        Integer target = calcDailyKcal(user, dto);
        if (target != null) {
            user.setDailyKcalTarget(target);
        }
        userMapper.updateById(user);
        return UserVO.of(user, latestWeight(user.getId()));
    }

    @Override
    public UserVO uploadAvatar(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException("请选择头像图片");
        }
        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new BizException("仅支持图片文件");
        }
        if (file.getSize() > 5 * 1024 * 1024) {
            throw new BizException("图片不能超过 5MB");
        }
        try {
            String url = ossService.upload("avatar", ".jpg",
                    new ByteArrayInputStream(file.getBytes()), file.getSize(),
                    org.springframework.http.MediaType.IMAGE_JPEG_VALUE);
            User user = requireUser();
            user.setAvatar(url);
            userMapper.updateById(user);
            return UserVO.of(user, latestWeight(user.getId()));
        } catch (Exception e) {
            throw new BizException("头像上传失败");
        }
    }


    // ===================== 正式账号体系 =====================

    @Override
    public void sendEmailCode(SendEmailCodeReqDTO dto) {
        // 注册用途: 邮箱已被注册则拒绝, 防止撞库枚举与无谓发信
        if (EmailVerificationService.REGISTER.equals(dto.getPurpose())) {
            User existing = userMapper.selectOne(new LambdaQueryWrapper<User>()
                    .eq(User::getEmail, normalizeEmail(dto.getEmail())).last("LIMIT 1"));
            if (existing != null) {
                throw new BizException(ResultCode.EMAIL_EXISTS);
            }
        } else {
            // 重置密码: 邮箱不存在也拒绝 (统一提示, 不暴露注册状态差异)
            User existing = userMapper.selectOne(new LambdaQueryWrapper<User>()
                    .eq(User::getEmail, normalizeEmail(dto.getEmail())).last("LIMIT 1"));
            if (existing == null) {
                throw new BizException("该邮箱尚未注册");
            }
        }
        emailVerificationService.send(dto.getEmail(), dto.getPurpose());
    }

    @Override
    @Transactional
    public Map<String, Object> register(PasswordRegisterReqDTO dto) {
        String username = dto.getUsername().trim();
        String email = normalizeEmail(dto.getEmail());

        User byName = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username).last("LIMIT 1"));
        if (byName != null) {
            throw new BizException(ResultCode.USERNAME_EXISTS);
        }
        User byEmail = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getEmail, email).last("LIMIT 1"));
        if (byEmail != null) {
            throw new BizException(ResultCode.EMAIL_EXISTS);
        }
        emailVerificationService.verifyAndConsume(email, EmailVerificationService.REGISTER, dto.getCode());

        User user = new User();
        user.setUsername(username);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(dto.getPassword()));
        user.setNickname(username);
        user.setTargetType("LOSE");
        user.setDailyKcalTarget(2200);
        try {
            userMapper.insert(user);
        } catch (org.springframework.dao.DuplicateKeyException e) {
            throw new BizException(ResultCode.USERNAME_EXISTS);
        }
        log.info("账号注册: id={} username={}", user.getId(), username);
        return loginResult(user);
    }

    @Override
    public Map<String, Object> passwordLogin(PasswordLoginReqDTO dto) {
        String account = dto.getUsername().trim();
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .and(w -> w.eq(User::getUsername, account).or().eq(User::getEmail, normalizeEmail(account)))
                .last("LIMIT 1"));
        if (user == null || !StringUtils.hasText(user.getPasswordHash())
                || !passwordEncoder.matches(dto.getPassword(), user.getPasswordHash())) {
            throw new BizException("账号或密码错误");
        }
        user.setLastLoginTime(java.time.LocalDateTime.now());
        userMapper.updateById(user);
        return loginResult(user);
    }

    @Override
    @Transactional
    public void resetPassword(ResetPasswordReqDTO dto) {
        String email = normalizeEmail(dto.getEmail());
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getEmail, email).last("LIMIT 1"));
        if (user == null || !StringUtils.hasText(user.getPasswordHash())) {
            throw new BizException("该邮箱尚未注册账号");
        }
        emailVerificationService.verifyAndConsume(email, EmailVerificationService.RESET_PASSWORD, dto.getCode());
        user.setPasswordHash(passwordEncoder.encode(dto.getNewPassword()));
        userMapper.updateById(user);
        log.info("密码重置: id={}", user.getId());
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase();
    }

    // ===================== 内部 =====================

    private User findOrRegister(String identifier, String nickname) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getAppleUserId, identifier).last("LIMIT 1"));
        if (user == null) {
            user = new User();
            user.setAppleUserId(identifier);
            user.setNickname(nickname);
            user.setTargetType("LOSE");
            user.setDailyKcalTarget(2200);
            userMapper.insert(user);
            log.info("新用户注册: {} ({})", nickname, identifier);
        }
        return user;
    }

    private Map<String, Object> loginResult(User user) {
        Map<String, Object> result = new HashMap<>();
        result.put("token", jwtUtil.issue(user.getId()));
        result.put("user", UserVO.of(user, latestWeight(user.getId())));
        return result;
    }

    private User requireUser() {
        User user = userMapper.selectById(UserContext.requireUserId());
        if (user == null) {
            throw new BizException(ResultCode.USER_NOT_FOUND);
        }
        return user;
    }

    private Double latestWeight(Long userId) {
        Weight weight = weightMapper.selectOne(new LambdaQueryWrapper<Weight>()
                .eq(Weight::getUserId, userId)
                .orderByDesc(Weight::getRecordDate)
                .last("LIMIT 1"));
        return weight != null ? weight.getWeightKg() : null;
    }

    /**
     * Mifflin-St Jeor:
     * BEE = 10*体重 + 6.25*身高 - 5*年龄 + (男 5 / 女 -161)
     * 目标 = BEE * 活动系数 + 目标调整 (减脂为负)
     */
    private Integer calcDailyKcal(User user, ProfileUpdateReqDTO dto) {
        Double weight = dto.getCurrentWeightKg() != null ? dto.getCurrentWeightKg() : latestWeight(user.getId());
        Double height = dto.getHeightCm() != null ? dto.getHeightCm() : user.getHeightCm();
        Integer birthYear = dto.getBirthYear() != null ? dto.getBirthYear() : user.getBirthYear();
        Integer gender = dto.getGender() != null ? dto.getGender() : user.getGender();
        if (weight == null || height == null || birthYear == null || gender == null) {
            return null;
        }
        int age = LocalDate.now().getYear() - birthYear;
        double bee = 10 * weight + 6.25 * height - 5 * age + (gender == 1 ? 5 : -161);

        double factor = dto.getActivityFactor() != null ? dto.getActivityFactor() : 1.2;
        String targetType = StringUtils.hasText(dto.getTargetType()) ? dto.getTargetType() : user.getTargetType();

        int paceAdjust = switch (dto.getPace() == null ? "MID" : dto.getPace()) {
            case "SLOW" -> 250;
            case "FAST" -> 750;
            default -> 500;
        };
        int direction = switch (targetType == null ? "LOSE" : targetType) {
            case "GAIN" -> 1;
            case "KEEP" -> 0;
            default -> -1;
        };

        int target = (int) Math.round(bee * factor + direction * paceAdjust);
        // 健康下限 (女性 1200 / 男性 1500)
        int floor = gender == 1 ? 1500 : 1200;
        return Math.max(target, floor);
    }
}
