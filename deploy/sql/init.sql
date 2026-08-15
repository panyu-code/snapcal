-- ============================================================
-- SnapCal 卡路里相机 初始化脚本
-- 数据库: snapcal (utf8mb4)
-- ============================================================
SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS `snapcal`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `snapcal`;

-- 用户表
CREATE TABLE IF NOT EXISTS `sc_user` (
  `id`               BIGINT       NOT NULL AUTO_INCREMENT,
  `apple_user_id`    VARCHAR(64)  NOT NULL COMMENT 'Apple sub / dev_xxx',
  `nickname`         VARCHAR(50)  DEFAULT '用户',
  `avatar`           VARCHAR(255) DEFAULT NULL,
  `gender`           TINYINT      DEFAULT NULL COMMENT '1男 2女',
  `birth_year`       INT          DEFAULT NULL,
  `height_cm`        DOUBLE       DEFAULT NULL,
  `target_type`      VARCHAR(10)  DEFAULT 'LOSE' COMMENT 'LOSE/KEEP/GAIN',
  `goal_weight_kg`   DOUBLE       DEFAULT NULL COMMENT '目标体重',
  `daily_kcal_target` INT         DEFAULT 2200 COMMENT '每日热量目标',
  `pro_expire_time`  DATETIME     DEFAULT NULL COMMENT 'Pro 到期时间',
  `create_time`      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_apple_user` (`apple_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 饮食记录(餐次)表
CREATE TABLE IF NOT EXISTS `sc_meal` (
  `id`           BIGINT PRIMARY KEY AUTO_INCREMENT,
  `user_id`      BIGINT       NOT NULL,
  `meal_type`    VARCHAR(10)  NOT NULL COMMENT 'BREAKFAST/LUNCH/DINNER/SNACK',
  `photo_url`    VARCHAR(500) DEFAULT NULL COMMENT '餐盘照片(RustFS)',
  `total_kcal`   INT          DEFAULT 0,
  `protein_g`    DOUBLE       DEFAULT 0,
  `carbs_g`      DOUBLE       DEFAULT 0,
  `fat_g`        DOUBLE       DEFAULT 0,
  `ai_confidence` DOUBLE      DEFAULT NULL,
  `eat_time`     DATETIME     NOT NULL,
  `create_time`  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_user_time` (`user_id`, `eat_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='餐次记录';

-- 餐次食物明细表
CREATE TABLE IF NOT EXISTS `sc_meal_item` (
  `id`          BIGINT PRIMARY KEY AUTO_INCREMENT,
  `meal_id`     BIGINT       NOT NULL,
  `food_name`   VARCHAR(100) NOT NULL,
  `weight_g`    INT          NOT NULL DEFAULT 100,
  `kcal`        INT          DEFAULT 0,
  `protein_g`   DOUBLE       DEFAULT 0,
  `carbs_g`     DOUBLE       DEFAULT 0,
  `fat_g`       DOUBLE       DEFAULT 0,
  `source`      VARCHAR(10)  DEFAULT 'AI' COMMENT 'AI/MANUAL/LIBRARY',
  INDEX `idx_meal` (`meal_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='餐次食物明细';

-- 食物营养成分库
CREATE TABLE IF NOT EXISTS `sc_food` (
  `id`           BIGINT PRIMARY KEY AUTO_INCREMENT,
  `name`         VARCHAR(100) NOT NULL,
  `emoji`        VARCHAR(8)   DEFAULT NULL COMMENT '食物emoji', 
  `category`     VARCHAR(30)  DEFAULT NULL,
  `kcal_per100g` INT         DEFAULT 0,
  `protein_per100g` DOUBLE   DEFAULT 0,
  `carbs_per100g` DOUBLE    DEFAULT 0,
  `fat_per100g` DOUBLE       DEFAULT 0,
  INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='食物库';

-- 体重记录表
CREATE TABLE IF NOT EXISTS `sc_weight` (
  `id`          BIGINT PRIMARY KEY AUTO_INCREMENT,
  `user_id`     BIGINT      NOT NULL,
  `weight_kg`   DOUBLE      NOT NULL,
  `record_date` DATE       NOT NULL,
  UNIQUE KEY `uk_user_date` (`user_id`, `record_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='体重记录';

-- 常用食物种子数据 (示例, M2 扩充完整库)
INSERT IGNORE INTO `sc_food` (`name`, `category`, `kcal_per100g`, `protein_per100g`, `carbs_per100g`, `fat_per100g`) VALUES
('米饭', '主食', 116, 2.6, 25.9, 0.3),
('馒头', '主食', 223, 7.0, 47.0, 1.1),
('全麦面包', '主食', 246, 9.0, 45.0, 3.4),
('鸡蛋', '蛋奶', 139, 13.3, 2.8, 8.8),
('牛奶', '蛋奶', 54, 3.0, 3.4, 3.2),
('鸡胸肉', '肉类', 133, 24.0, 0.0, 3.0),
('红烧鸡腿', '肉类', 204, 19.0, 5.0, 12.0),
('牛腩', '肉类', 332, 17.1, 0.0, 28.8),
('三文鱼', '水产', 139, 17.2, 0.0, 7.8),
('西兰花', '蔬菜', 34, 2.8, 3.7, 0.4),
('番茄', '蔬菜', 18, 0.9, 3.9, 0.2),
('黄瓜', '蔬菜', 15, 0.7, 2.9, 0.1),
('苹果', '水果', 53, 0.4, 13.7, 0.2),
('香蕉', '水果', 93, 1.4, 22.0, 0.2),
('酸奶', '蛋奶', 72, 2.8, 9.3, 2.7),
('燕麦', '主食', 367, 15.0, 61.0, 6.7);
