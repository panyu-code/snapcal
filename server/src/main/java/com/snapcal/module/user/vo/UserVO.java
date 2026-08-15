package com.snapcal.module.user.vo;

import com.snapcal.module.user.entity.User;
import lombok.Data;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
public class UserVO implements Serializable {

    private Long id;
    private String nickname;
    private String avatar;
    private Integer gender;
    private Integer birthYear;
    private Double heightCm;
    private String targetType;
    private Double goalWeightKg;
    private Integer dailyKcalTarget;
    /** 最新体重 (无记录为 null) */
    private Double currentWeightKg;
    private Boolean isPro;
    private LocalDateTime createTime;

    public static UserVO of(User user, Double currentWeightKg) {
        UserVO vo = new UserVO();
        vo.setId(user.getId());
        vo.setNickname(user.getNickname());
        vo.setAvatar(user.getAvatar());
        vo.setGender(user.getGender());
        vo.setBirthYear(user.getBirthYear());
        vo.setHeightCm(user.getHeightCm());
        vo.setTargetType(user.getTargetType());
        vo.setGoalWeightKg(user.getGoalWeightKg());
        vo.setDailyKcalTarget(user.getDailyKcalTarget());
        vo.setCurrentWeightKg(currentWeightKg);
        vo.setIsPro(user.getProExpireTime() != null
                && user.getProExpireTime().isAfter(LocalDateTime.now()));
        vo.setCreateTime(user.getCreateTime());
        return vo;
    }
}
