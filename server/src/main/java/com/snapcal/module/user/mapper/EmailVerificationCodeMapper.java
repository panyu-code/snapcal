package com.snapcal.module.user.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.snapcal.module.user.entity.EmailVerificationCode;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface EmailVerificationCodeMapper extends BaseMapper<EmailVerificationCode> {

    @Select("""
            SELECT id, email, purpose, code_hash, failed_attempts, expires_at,
                   sent_at, consumed_at, create_time, update_time
            FROM sc_email_verification_code
            WHERE email = #{email} AND purpose = #{purpose}
            FOR UPDATE
            """)
    EmailVerificationCode selectForUpdate(@Param("email") String email,
                                          @Param("purpose") String purpose);
}
