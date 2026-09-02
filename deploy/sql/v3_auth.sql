-- ============================================================
-- SnapCal v3 认证体系迁移: 正式账号 (用户名/密码/邮箱)
-- 执行: docker exec -i dataviz-mysql mysql -uroot -pYuPan95270. snapcal < v3_auth.sql
-- 注意: 本脚本为一次性迁移 (重复执行会报重复列/索引, 属预期)
-- ============================================================

-- 1. apple_user_id 兼容空值 (纯邮箱/用户名账号不填)
ALTER TABLE sc_user
    MODIFY COLUMN apple_user_id VARCHAR(255) NULL COMMENT 'Apple sub 标识(旧数据含前缀), 本地账号为空';

-- 2. 正式账号字段
ALTER TABLE sc_user
    ADD COLUMN username      VARCHAR(30)  NULL COMMENT '用户名(唯一)' AFTER apple_user_id,
    ADD COLUMN password_hash VARCHAR(100) NULL COMMENT 'BCrypt 密码哈希' AFTER username,
    ADD COLUMN email         VARCHAR(254) NULL COMMENT '邮箱(小写,唯一)' AFTER password_hash,
    ADD COLUMN email_verified TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '邮箱验证状态' AFTER email,
    ADD COLUMN last_login_time DATETIME    NULL COMMENT '最近登录时间' AFTER pro_expire_time;

-- 3. 唯一索引 (兼容历史数据: 旧 Apple/dev 用户这些字段均为 NULL)
ALTER TABLE sc_user
    ADD UNIQUE KEY uk_user_username (username),
    ADD UNIQUE KEY uk_user_email (email);

-- 4. 邮箱验证码表
CREATE TABLE IF NOT EXISTS sc_email_verification_code (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(254) NOT NULL COMMENT '收件邮箱(小写)',
    purpose         VARCHAR(20)  NOT NULL COMMENT 'REGISTER / RESET_PASSWORD',
    code_hash       VARCHAR(100) NOT NULL COMMENT 'BCrypt 验证码哈希',
    failed_attempts INT NOT NULL DEFAULT 0 COMMENT '连续错误次数',
    expires_at      DATETIME NOT NULL COMMENT '过期时间',
    sent_at         DATETIME NULL COMMENT '最近发送时间',
    consumed_at     DATETIME NULL COMMENT '消费时间(一次性)',
    create_time     DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time     DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_email_purpose (email, purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='邮箱验证码(一次性, 限时)';
