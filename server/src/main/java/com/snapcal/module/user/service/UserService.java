package com.snapcal.module.user.service;

import com.snapcal.module.user.dto.AppleLoginReqDTO;
import com.snapcal.module.user.dto.DevLoginReqDTO;
import com.snapcal.module.user.dto.ProfileUpdateReqDTO;
import com.snapcal.module.user.vo.UserVO;

import java.util.Map;

public interface UserService {

    /** Apple 登录: 返回 {token, user} */
    Map<String, Object> appleLogin(AppleLoginReqDTO dto);

    /** 开发模式登录: 返回 {token, user} */
    Map<String, Object> devLogin(DevLoginReqDTO dto);

    /** 当前用户信息 */
    UserVO me();

    /** 更新资料并重算每日热量目标 */
    UserVO updateProfile(ProfileUpdateReqDTO dto);
}
