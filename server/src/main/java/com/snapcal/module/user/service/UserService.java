package com.snapcal.module.user.service;

import com.snapcal.module.user.dto.AppleLoginReqDTO;
import com.snapcal.module.user.dto.PasswordLoginReqDTO;
import com.snapcal.module.user.dto.PasswordRegisterReqDTO;
import com.snapcal.module.user.dto.ResetPasswordReqDTO;
import com.snapcal.module.user.dto.SendEmailCodeReqDTO;
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

    /** 上传头像 */
    UserVO uploadAvatar(org.springframework.web.multipart.MultipartFile file);

    /** 发送邮箱验证码 (注册/找回密码) */
    void sendEmailCode(SendEmailCodeReqDTO dto);

    /** 用户名密码注册: 返回 {token, user} */
    Map<String, Object> register(PasswordRegisterReqDTO dto);

    /** 账号密码登录: 返回 {token, user} */
    Map<String, Object> passwordLogin(PasswordLoginReqDTO dto);

    /** 邮箱验证码重置密码 */
    void resetPassword(ResetPasswordReqDTO dto);
}
