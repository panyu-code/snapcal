# 📸 SnapCal 卡路里相机

> 拍一张餐盘照片 → AI 识别菜品并估算热量与三大营养素 → 一键记录，科学管理饮食。
> iOS 原生应用（SwiftUI）+ 自有 Java 后端 + 多模态 AI 视觉识别。

<p align="center">
  <b>SwiftUI · iOS 17+ · Java Spring Boot 3 · 多模态 AI · HealthKit · Docker</b>
</p>

---

## 📑 目录

- [一、项目简介](#一项目简介)
- [二、核心功能](#二核心功能)
- [三、原型图](#三原型图)
- [四、技术架构](#四技术架构)
- [五、AI 识别方案](#五ai-识别方案)
- [六、数据库设计](#六数据库设计)
- [七、API 设计](#七api-设计)
- [八、iOS 工程结构](#八ios-工程结构)
- [九、开发里程碑](#九开发里程碑)
- [十、部署方案](#十部署方案)
- [十一、变现策略](#十一变现策略)

---

## 一、项目简介

### 1.1 解决什么问题

减肥/健身/控糖人群每天最烦三件事：**不知道吃了多少热量、手动查食物库太麻烦、坚持记录太难**。

传统卡路里 App（薄荷健康等）需要手动搜索每个食物、估算克重，一餐要操作 1-2 分钟，绝大多数用户 7 天内流失。

**SnapCal 的答案：拍一张照片，3 秒完成记录。**

| 对比项 | 传统 App | SnapCal |
|--------|---------|---------|
| 记录一餐 | 搜索+逐项录入 60-120s | 拍照 3s |
| 克重估算 | 用户自己猜 | AI 按图片体积估算 |
| 记录动力 | 操作繁琐易放弃 | 拍照本身有趣，易坚持 |

### 1.2 目标用户

- 减脂/增肌健身人群（核心，付费意愿强）
- 控糖控血压的慢病人群（家属代拍）
- 关注健康的普通白领

### 1.3 核心价值

- 📷 **拍照即记录**：多模态 AI 识别菜品 + 估算克重与营养
- ✏️ **可修正**：识别结果可调克重、可从食物库换菜品（保底准确性）
- 📊 **可视化**：卡路里圆环、摄入趋势、体重曲线
- ⌚ **生态联动**：Apple 健康（步数/消耗）、桌面 Widget、Apple Watch 快速记录

---

## 二、核心功能

```
SnapCal
├── 📷 拍照识别（核心）
│   ├── 相机取景 + 引导框
│   ├── 后端 AI 识别（菜品/克重/热量/营养素/置信度）
│   ├── 结果确认页：逐项调整克重（步进器）
│   ├── 识别不准 → 搜索食物库手动替换
│   └── 相册导入 + 历史照片补录
│
├── 🍽️ 饮食记录
│   ├── 今日圆环（摄入/目标）+ 三大营养素进度
│   ├── 早餐/午餐/晚餐/加餐 四类餐次
│   └── 按天分组的历史流水
│
├── 📊 趋势统计
│   ├── 每日摄入柱状图（超标变红 + 目标虚线）
│   ├── 体重趋势折线
│   ├── 周/月切换 + 达标天数统计
│   └── 常吃食物 TOP 榜
│
├── 👤 目标管理
│   ├── 减脂/维持/增肌 + 快中慢速
│   ├── 自动计算每日热量目标（Mifflin-St Jeor 公式）
│   └── 体重记录 + 目标达成预测
│
├── ⌚ iOS 生态
│   ├── HealthKit 双向同步（读取消耗/写入膳食）
│   ├── 桌面 Widget（今日剩余热量）
│   └── Apple Watch 快捷查看（M4 后可选）
│
└── 💰 商业化
    ├── 免费：每日 3 次 AI 识别
    └── Pro（订阅/买断）：无限识别 + 全量趋势 + 导出
```

---

## 三、原型图

高保真原型：**`prototype/index.html`**（浏览器直接打开）

| # | 页面 | 关键元素 |
|---|------|---------|
| ① | 今日首页 | 卡路里圆环（354/2200）· 三大营养素进度条 · 餐次列表 · 悬浮拍照按钮 |
| ② | 拍照识别 | 相机取景框 · 四角边界 · 扫描光线动画 · "AI 识别中"状态 |
| ③ | 结果确认 | 菜品列表（米饭/鸡腿/西兰花）· 克重步进器 · 热量小计 · 置信度 · 保存按钮 |
| ④ | 饮食记录 | 按天分组卡片流 · 食物明细标签 · 每日热量汇总 |
| ⑤ | 趋势统计 | 7 日摄入柱状图（超标红色）· 体重折线 · 达标统计卡 |
| ⑥ | 我的 | 减脂目标进度（开始/当前/目标）· HealthKit 入口 · Pro 订阅 |

设计规范：iPhone 14 Pro（390×844）· 深色健康风 · 主色 `#34D399` · SF Pro / 苹方

---

## 四、技术架构

```
┌──────────────────────────────────────────────┐
│              iPhone (SwiftUI)                │
│  相机/相册 · 圆环/图表 · HealthKit · Widget   │
│         本地缓存(SQLite) + 离线可用           │
└───────────────┬──────────────────────────────┘
                │ HTTPS (JWT)
                ▼
┌──────────────────────────────────────────────┐
│      Java 后端 (你的服务器 · Docker)          │
│  Spring Boot 3 · JWT 鉴权 · 图片压缩存储      │
│  食物库 · 记录/统计 API · 订阅校验(IAP)       │
└──────┬───────────────────────┬───────────────┘
       │                       │
       ▼                       ▼
┌──────────────┐      ┌──────────────────┐
│  多模态 AI    │      │  对象存储(RustFS) │
│ 视觉识别服务  │      │  餐盘照片持久化    │
└──────────────┘      └──────────────────┘
```

### 技术栈清单

| 层 | 技术 | 说明 |
|----|------|------|
| iOS | Swift 5.9 + SwiftUI | iOS 17+，Observable 宏 |
| iOS 依赖 | Alamofire / Kingfisher / Charts | 网络请求按需可换 URLSession |
| 本地存储 | SwiftData（或 GRDB） | 离线记录 + 云端同步 |
| 后端 | Spring Boot 3 + JDK 17 | 复用现有工程风格 |
| 数据库 | MySQL 8（Docker） | 用户/记录/食物库 |
| 对象存储 | RustFS（已有） | 餐盘照片 |
| AI | 多模态大模型 API | 详见下节 |
| 认证 | JWT（手机号/Apple 登录） | **必须支持 Sign in with Apple**（上架要求） |

---

## 五、AI 识别方案

### 5.1 模型选择（后端可配置切换）

| 方案 | 模型 | 特点 |
|------|------|------|
| 首选 | GLM-4V-Flash / 通义 Qwen-VL | 国内直连、中文菜品识别强、价格低 |
| 备选 | GPT-4o / Claude Sonnet | 识别质量高，成本较高 |
| 演进 | 自部署 YOLO + 营养库匹配 | 零边际成本，精度依赖训练 |

### 5.2 识别链路

```
App 拍照 → 压缩(1280px, ~200KB) → 上传后端
  → 后端存 RustFS → 调多模态 API（结构化 Prompt）
  → 返回 JSON：[{name, weight_g, calories, protein, carbs, fat, confidence}]
  → 后端按食物库校准热量 → 返回 App
  → 用户确认/修正 → 落库
```

### 5.3 核心 Prompt（结构化输出）

```
你是营养分析专家。分析这张餐盘照片，识别所有食物。
严格输出 JSON 数组，每项：
{"name":"菜品中文名","weight_g":估算克重,"calories":该重量热量kcal,
 "protein":蛋白质g,"carbs":碳水g,"fat":脂肪g,"confidence":0-1}
要求：weight_g 按图片中食物典型份量估算；只输出 JSON。
```

### 5.4 准确性兜底（关键设计）

AI 估算天然有误差，产品上必须三层兜底：
1. **结果页可调**：克重步进器 ±10g 实时重算热量
2. **食物库替换**：识别错了 → 搜索 10 万条中国食物营养成分库（USDA + 中国食物成分表开源数据）手动替换
3. **用户校正学习**：用户修正过的"同一菜品克重"进入个人习惯（下次预填）

---

## 六、数据库设计

```sql
-- 用户
CREATE TABLE sc_user (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  apple_user_id VARCHAR(64) UNIQUE COMMENT 'Apple Sign In 标识',
  nickname VARCHAR(50),
  avatar VARCHAR(255),
  gender TINYINT COMMENT '1男2女',
  birth_year INT, height_cm DECIMAL(4,1),
  target_type VARCHAR(10) DEFAULT 'LOSE' COMMENT 'LOSE/KEEP/GAIN',
  daily_kcal_target INT DEFAULT 2200,
  pro_expire_time DATETIME COMMENT 'Pro 到期',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 饮食记录（餐次）
CREATE TABLE sc_meal (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  meal_type VARCHAR(10) NOT NULL COMMENT 'BREAKFAST/LUNCH/DINNER/SNACK',
  photo_url VARCHAR(255) COMMENT 'RustFS 地址',
  total_kcal INT, protein_g DECIMAL(6,1),
  carbs_g DECIMAL(6,1), fat_g DECIMAL(6,1),
  ai_confidence DECIMAL(4,3),
  eat_time DATETIME NOT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_time (user_id, eat_time)
);

-- 餐次内食物明细
CREATE TABLE sc_meal_item (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  meal_id BIGINT NOT NULL,
  food_name VARCHAR(100) NOT NULL,
  weight_g INT NOT NULL,
  kcal INT, protein_g DECIMAL(6,1),
  carbs_g DECIMAL(6,1), fat_g DECIMAL(6,1),
  source VARCHAR(10) DEFAULT 'AI' COMMENT 'AI/MANUAL/LIBRARY',
  INDEX idx_meal (meal_id)
);

-- 食物库（初始化导入）
CREATE TABLE sc_food (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(30),
  kcal_per_100g INT, protein_per_100g DECIMAL(5,1),
  carbs_per_100g DECIMAL(5,1), fat_per_100g DECIMAL(5,1),
  INDEX idx_name (name)
);

-- 体重记录
CREATE TABLE sc_weight (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  weight_kg DECIMAL(4,1) NOT NULL,
  record_date DATE NOT NULL,
  UNIQUE KEY uk_user_date (user_id, record_date)
);
```

---

## 七、API 设计

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/apple` | Apple 登录（identityToken 校验） |
| GET | `/api/user/me` | 个人资料 + 目标 |
| PUT | `/api/user/profile` | 更新身高/目标等 → 重算每日热量 |
| **POST** | **`/api/vision/recognize`** | **上传餐盘照片 → AI 返回识别结果**（核心） |
| POST | `/api/meal` | 保存餐次（含明细 JSON） |
| GET | `/api/meal/day?date=` | 某日全部餐次 |
| GET | `/api/meal/page?start=&end=` | 记录分页 |
| DELETE | `/api/meal/{id}` | 删除餐次 |
| GET | `/api/stats/daily?days=7` | 每日摄入汇总（趋势图） |
| GET | `/api/stats/weight?days=30` | 体重序列 |
| POST | `/api/weight` | 记录体重 |
| GET | `/api/food/search?kw=` | 食物库搜索（修正用） |
| GET | `/api/food/list` | 食物库分页浏览（名称/类别筛选） |
| GET | `/api/food/categories` | 食物库分类列表 |
| GET | `/api/food/favorites` | 我的收藏食物 |
| POST | `/api/food/favorites/{foodId}/toggle` | 收藏/取消收藏（幂等切换） |
| GET | `/api/food/recent` | 常吃食物（最近记录自动推荐） |
| PUT | `/api/meal/{id}` | 编辑餐次（类型/备注/份量，营养重算） |
| GET | `/api/water/today` | 今日饮水汇总 |
| POST | `/api/water` | 饮水（正数计入 / 负数撤销） |
| GET | `/api/water/range?days=7` | 最近 N 天饮水 |
| POST | `/api/user/avatar` | 上传头像 |

`recognize` 响应示例：
```json
{
  "code": 200,
  "data": {
    "image": "https://oss.../meal_123.jpg",
    "items": [
      {"name": "米饭", "weight_g": 200, "kcal": 232, "protein": 5.1, "carbs": 49.5, "fat": 0.6, "confidence": 0.97},
      {"name": "红烧鸡腿", "weight_g": 120, "kcal": 245, "protein": 22.8, "carbs": 4.2, "fat": 14.1, "confidence": 0.92}
    ]
  }
}
```

---

## 八、iOS 工程结构

```
SnapCal/
├── SnapCalApp.swift            # 入口
├── Features/
│   ├── Today/                  # ① 今日首页（圆环/营养素/餐次）
│   ├── Camera/                 # ② 拍照（AVFoundation + 权限）
│   ├── Recognize/              # ③ 结果确认（步进器/食物库替换）
│   ├── History/                # ④ 饮食记录流水
│   ├── Trends/                 # ⑤ 趋势（Swift Charts）
│   └── Profile/                # ⑥ 我的（目标/订阅/HealthKit）
├── Core/
│   ├── Network/                # API Client（JWT 拦截/刷新）
│   ├── Models/                 # Meal/Food/User
│   ├── Storage/                # SwiftData 离线缓存
│   └── HealthKit/              # HK 桥接
├── Widget/                     # 桌面小组件（今日剩余）
└── Resources/
```

---

## 九、开发里程碑

> 前置：Mac + Xcode 15 + Apple 开发者账号（¥688/年，上架必需）

### M1 — iOS 工程基建 ✅ 已完成
- [x] Xcode 工程（xcodegen 生成）+ SwiftUI 五 Tab 框架
- [x] Apple 登录（后端 JWKS 拉取 + RS256 验签）+ 开发模式登录
- [x] 网络层（统一响应/JWT/Keychain→UserDefaults）+ 资料/目标设置页
- [x] 后端已部署 `myblog.wiki:8081`（Docker + MySQL）

### M2 — 核心链路：拍照 → AI → 保存 ✅ 已完成
- [x] 真机相机（AVFoundation 拍照/权限/快门）+ 模拟器相册回退
- [x] 后端 `/vision/recognize`：图片压缩 → RustFS 存储 → **智谱 GLM-4V-Flash 真实识别**（可切换 provider）
- [x] 结果确认页：克重步进器实时重算 + 扫描线动效 + 识别中显示原图背景
- [x] **食物库搜索替换**（识别错了手动换）+ **食物项删除**
- [x] 食物库 **622 种**常见食物（15 大类，每 100g 营养齐全）
- [x] 餐次保存 API（自动汇总营养）+ 按日/区间查询

### M3 — 今日与记录 ✅ 已完成
- [x] 今日圆环 + 三大营养素进度（真实数据）
- [x] 饮食记录流水页（按天分组/删除/下拉刷新）
- [x] **餐次详情页**（照片大图 + 食物明细 + 营养汇总 + 删除）
- [x] SwiftData 离线缓存（断网可看历史）+ 保存后实时刷新（通知联动）

### M4 — 趋势与目标 ✅ 已完成
- [x] Swift Charts 摄入柱状图（周/月，超标红色，数值标注，月视图横滑）
- [x] 体重折线 + 记体重弹窗
- [x] 目标计算（Mifflin-St Jeor，健康下限保护）
- [x] HealthKit 同步（读步数/活动消耗 + 写膳食能量）

### M5 — 打磨与 Widget 🟡 部分完成
- [x] 识别扫描线动效 + 空态 + **首次启动引导页**（3 页滑动）
- [x] **主题系统**（深色/浅色/跟随系统，我的页切换）
- [x] **头像编辑**（选图 → 缩放预览 → 保存按钮，上传 RustFS）
- [x] **食物库浏览**（我的页入口：搜索 + 19 分类筛选 + 分页列表 + 营养参数）
- [x] **食物 emoji 精准匹配**（622 种入库，加新食物 INSERT 带 emoji 即可，无需改代码）
- [x] App 图标（仪表盘风格 V10 增强版，多版设计可选）
- [x] Widget 代码已完成（今日剩余热量圆环，小/中尺寸）
- [ ] Widget 上线（需付费开发者账号的 App Group 权限，当前从免费签名工程中移除，代码保留在 `SnapCalWidget/`）
- [ ] 免费 3 次/日限制 + IAP 订阅（暂缓）

### M7 — 记录效率与体验大升级 ✅ 已完成
- [x] **手动记录餐食**（不拍照也能记：餐次类型 + 食物搜索/收藏/常吃快捷添加 + 份量实时重算 + 备注；今日页餐次行与右上角 + 均可进入）
- [x] **食物收藏 + 常吃推荐**（搜索结果/手动添加中一键星标收藏；「常吃」按最近记录自动推荐，一键入餐）
- [x] **今日饮水打卡**（+200/+500 快捷按钮、撤销、2000ml 目标进度条、达标提示；`sc_water_log` 表 + 接口）
- [x] **餐次编辑**（详情页可改餐次类型/备注/每项份量/删项，营养按比例自动重算，PUT /meal/{id}）
- [x] **餐次备注**（保存时可选填，记录页/详情页展示）
- [x] **抖音式即时搜索**（输入 300ms 防抖自动搜索 + 命中关键词品牌绿高亮，食物库与替换弹窗统一）
- [x] **用餐提醒通知**（我的页设置：开关 + 早/午/晚三个时间点，本地通知每日重复）
- [x] **离线登录态修复**（启动网络抖动不再掉登录页，缓存用户直接进主界面，仅明确 401 才登出）
- [x] **触感反馈**（点按/成功/删除轻震动，真机生效）
- [x] **XCUITest 端到端自动化测试**（4 条用例：今日水卡 / 手动记录全流程 / 记录详情编辑入口 / 提醒设置，`xcodebuild test` 一键回归）

### M6 — 上架 ⏳ 待办
- [ ] 付费开发者账号（¥688/年）
- [ ] TestFlight 内测
- [ ] 后端切 HTTPS（`api.myblog.wiki` + 证书）
- [ ] App Store 审核材料（健康数据用途说明、AI 功能标注、隐私政策）

**开发侧全部完成**（除上架），后端运行中，真机可完整使用（免费证书 7 天重签）。

---

## 十、部署方案（当前实际状态）

后端已部署在 `myblog.wiki`（腾讯云，与 DataViz 共用服务器）：

```
/opt/snapcal/server/
├── snapcal-server:0.5  # Docker 容器 (端口 8081, context-path /api)
├── restart.sh          # 重启脚本 (环境变量注入 + 日志快照)
└── snapcal.log         # 日志文件

依赖服务 (复用 dataviz 实例):
├── dataviz-mysql       # snapcal 数据库 (5 张表 + 622 食物)
└── dataviz-rustfs      # 对象存储 (snapcal bucket 公开读, 存餐盘照片/头像)
```

- 接口地址：`http://myblog.wiki:8081/api`（真机直连，ATS 已放行 HTTP）
- 视觉 AI：智谱 GLM-4V-Flash（key 经环境变量注入 restart.sh）
- 上架前需切 HTTPS：`api.myblog.wiki` 子域名 + Let's Encrypt 证书 + 关闭 DEV_MODE

---

## 十一、变现策略

| 模式 | 定价 | 说明 |
|------|------|------|
| 免费 | 每日 3 次识别 | 覆盖一日三餐，先养习惯 |
| Pro 订阅 | ¥68/年 | 无限识别 + 全量统计 + 数据导出 + Widget |
| 买断（可选） | ¥98 | 买断制用户偏好，A/B 测试 |

健康/健身类 iOS 用户 LTV 高，参考同类独立产品（Cal AI 上线数月百万美元营收）。

---

> **SnapCal** — 拍一下，吃明白。📸
