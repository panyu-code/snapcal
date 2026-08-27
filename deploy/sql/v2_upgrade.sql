-- ============================================================
-- SnapCal v2 功能升级脚本 (手动记录/收藏/饮水/餐次备注)
-- 在 MySQL 容器内执行: docker exec -i dataviz-mysql mysql -uroot -pYuPan95270. snapcal < v2_upgrade.sql
-- ============================================================

-- 1. 餐次备注
ALTER TABLE sc_meal ADD COLUMN note VARCHAR(200) NULL AFTER ai_confidence;

-- 2. 饮水记录
CREATE TABLE IF NOT EXISTS sc_water_log (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  log_date DATE NOT NULL,
  amount_ml INT NOT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_date (user_id, log_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='饮水记录';

-- 3. 食物收藏
CREATE TABLE IF NOT EXISTS sc_food_favorite (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  food_id BIGINT NOT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_food (user_id, food_id),
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='食物收藏';
