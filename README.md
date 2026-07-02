# 纯享 (Pure Enjoy)

一个免费的小说阅读与生活记录 App，无广告，简洁优雅。

> **项目拆分说明**：后台管理系统已独立到 [pure-enjoy-admin](https://github.com/youpgc/pure-enjoy-admin) 仓库

## ✨ 功能特性

### 📖 小说阅读
- 书架管理与阅读进度自动保存
- 小说发现与详情浏览
- 章节评论与互动
- 阅读器设置：字体大小、背景颜色（护眼/白色/夜间）、翻页动画
- 目录导航与离线缓存

### ✍️ 生活记录
- **消费记录** — 分类记账，统计支出
- **心情日记** — 记录每日心情，支持表情选择
- **体重记录** — 追踪体重变化趋势
- **笔记本** — 随时记录想法，支持置顶
- **收藏夹** — 收藏网页链接，支持标签
- **习惯打卡** — 每日习惯追踪，连续打卡统计
- **提醒事项** — 待办提醒，支持重复周期
- **纪念日** — 记录重要日期，农历/公历支持
- **用户反馈** — 提交建议与问题

### 🔐 用户系统
- 邮箱/用户名/手机号登录（统一走 Supabase Auth）
- 180 天会话有效期，自动过期清理
- 云端数据同步（Supabase）+ 本地离线缓存
- 数据导出

### 🔄 版本更新
- 内置版本检查，支持强制/普通更新
- 双源下载：优先 Gitee（国内快），失败自动回退 GitHub

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### 安装依赖

```bash
cd pure-enjoy
flutter pub get
```

### 运行项目

```bash
# 开发模式
flutter run

# 或指定设备
flutter run -d <device_id>
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

## 📁 项目结构

```
pure-enjoy/
├── lib/
│   ├── constants/          # 角色常量等
│   ├── core/
│   │   ├── models/         # 数据模型（字典等）
│   │   ├── theme/          # 主题系统（8 种配色 + Provider）
│   │   ├── utils/          # 工具类（事件总线等）
│   │   └── widgets/        # 通用组件（Loading/Empty/Error/分页骨架屏）
│   ├── features/
│   │   ├── auth/           # 认证模块（登录/注册）
│   │   ├── home/           # 首页、个人资料、设置、通知中心
│   │   ├── life/           # 生活记录模块（消费/心情/体重/笔记/收藏/习惯/提醒/纪念日/反馈）
│   │   ├── novel/          # 小说模块（发现/书架/阅读器/评论）
│   │   └── profile/        # 积分记录
│   ├── services/           # 服务层
│   │   ├── api_client.dart          # 统一 API 封装
│   │   ├── auth_api.dart            # Supabase Auth REST 调用
│   │   ├── session_manager.dart     # Token 持久化 + 180 天过期检查
│   │   ├── http_client.dart         # HTTP 客户端，自动注入 JWT
│   │   ├── supabase_service.dart    # 认证门面
│   │   ├── storage_service.dart     # 文件存储
│   │   ├── dict_service.dart        # 字典服务
│   │   ├── notification_service.dart # 本地通知
│   │   ├── offline_sync_service.dart # 离线同步
│   │   ├── sensitive_word_service.dart # 敏感词过滤
│   │   ├── chapter_cache_service.dart  # 章节缓存
│   │   ├── data_export_service.dart    # 数据导出
│   │   └── version_check_service.dart  # 版本检查 + 双源下载
│   ├── utils/              # 辅助工具（缓存、日期、格式化）
│   ├── widgets/            # 通用组件
│   ├── config.dart         # 全局配置（表名、存储桶）
│   └── main.dart           # 应用入口
├── android/                # Android 配置
├── assets/                 # 静态资源（图片、字体）
└── test/                   # 单元测试
```

## 🛠 技术栈

- **Flutter 3.44.x** — 跨平台 UI 框架
- **Dart 3.12.x**
- **flutter_riverpod** — 状态管理
- **http** — 直接访问 Supabase REST API
- **shared_preferences** — 本地键值存储（Token 持久化）
- **path_provider** — 文件路径
- **open_filex** — 安装 APK
- **package_info_plus** — 版本信息
- **flutter_local_notifications** — 本地通知
- **image_picker** — 头像上传
- **fl_chart** — 图表
- **shimmer** — 骨架屏
- **Supabase** — 云端服务（认证 + PostgreSQL + 存储）

## 🔧 配置说明

### Supabase 配置

项目使用 `--dart-define` 注入环境变量，无需在源码中硬编码：

```bash
flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

CI 构建时通过 GitHub Secrets 注入。

### 数据库表结构

后端表结构见 `pure-enjoy-admin/database/schema.sql`，主要业务表包括：

- `users` / `profiles` — 用户与资料
- `expenses` / `mood_diaries` / `weight_records` / `notes` / `user_favorites` / `user_habits` / `habit_checkins` / `user_reminders` / `anniversaries` — 生活记录
- `novels` / `novel_chapters` / `novel_comments` / `user_novels` — 小说
- `app_versions` — App 版本管理（含 Gitee/GitHub 双下载链接）
- `app_configs` / `dicts` / `sensitive_words` / `operation_logs` / `error_logs` — 系统配置

## 📦 CI/CD

推送 `master` 分支自动触发 GitHub Actions：

1. 自动递增版本号（patch + build）
2. 构建 Release APK（混淆 + 树摇优化）
3. 同时发布到：
   - **Gitee** `pure-enjoy-releases`（国内主下载源，公开仓库）
   - **GitHub Releases**（备份源）
4. 双端均只保留最新 5 个 Release
5. 向 Supabase `app_versions` 表插入版本记录

## 🔗 相关仓库

- **App 端**（当前仓库）：Flutter 跨平台应用
- **后台管理**：[pure-enjoy-admin](https://github.com/youpgc/pure-enjoy-admin) — React + Ant Design 管理后台

## 📄 许可证

MIT License

---

Made with ❤️ by 纯享团队
