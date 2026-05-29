# 纯享 (Pure Enjoy)

一个免费的小说阅读与生活记录App，无广告，简洁优雅。

> 🔔 **项目拆分说明**：后台管理系统已独立到 [pure-enjoy-admin](https://github.com/youpgc/pure-enjoy-admin) 仓库

## ✨ 功能特性

### 📖 小说阅读
- 书架管理
- 小说发现
- 阅读进度自动保存
- 字体大小调节
- 背景颜色切换（护眼/白色/夜间）
- 目录导航

### ✍️ 生活记录
- **消费记录** - 分类记账，统计支出
- **心情日记** - 记录每日心情，支持表情选择
- **体重记录** - 追踪体重变化趋势
- **笔记本** - 随时记录想法，支持置顶
- **收藏夹** - 收藏网页链接，支持标签
- **习惯打卡** - 每日习惯追踪，连续打卡统计
- **提醒事项** - 待办提醒，优先级设置

### 🔐 用户系统
- 邮箱登录/注册
- 云端数据同步（Supabase）
- 本地离线使用

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

# iOS
flutter build ios --release
```

## 📁 项目结构

```
pure-enjoy/
├── lib/
│   ├── core/
│   │   ├── constants/      # 常量配置
│   │   ├── theme/          # 主题配置
│   │   ├── utils/          # 工具类
│   │   └── widgets/        # 通用组件
│   ├── features/
│   │   ├── auth/           # 认证模块
│   │   ├── home/           # 首页模块
│   │   ├── life/           # 生活记录模块
│   │   │   ├── models/     # 数据模型
│   │   │   └── screens/    # UI页面
│   │   ├── novel/          # 小说模块
│   │   └── profile/        # 个人中心
│   ├── services/           # 服务层
│   │   ├── database_service.dart   # 本地数据库
│   │   ├── storage_service.dart    # 本地存储
│   │   ├── supabase_service.dart   # 云端服务
│   │   ├── sync_service.dart       # 数据同步
│   │   └── version_check_service.dart # 版本检查
│   ├── config.dart         # 全局配置
│   └── main.dart           # 应用入口
├── android/                # Android 配置
├── assets/                 # 静态资源
├── supabase/               # 数据库脚本
│   ├── schema.sql          # 业务表结构
│   ├── schema_complete.sql # 完整表结构
│   └── migration_complete.sql # 迁移脚本
└── README.md
```

## 🔗 相关仓库

- **App 端**（当前仓库）：Flutter 跨平台应用
- **后台管理**：[pure-enjoy-admin](https://github.com/youpgc/pure-enjoy-admin) - React + Ant Design 管理后台

## 🛠 技术栈

- **Flutter** - 跨平台UI框架
- **Provider** - 状态管理
- **Sqflite** - 本地数据库存储
- **SharedPreferences** - 本地键值存储
- **Supabase** - 云端服务（认证+数据库+存储）
- **intl** - 国际化与日期格式化

## 🔧 配置说明

### Supabase 配置

项目已配置好Supabase，如需修改，请编辑：

```dart
// lib/config.dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 数据库表结构

需要在Supabase中创建以下表：

1. **users** - 用户表
2. **expenses** - 消费记录
3. **mood_diaries** - 心情日记
4. **weight_records** - 体重记录
5. **notes** - 笔记
6. **user_favorites** - 收藏夹
7. **user_reminders** - 提醒事项
8. **user_habits** - 习惯打卡
9. **habit_checkins** - 打卡记录
10. **novels** - 小说表
11. **novel_chapters** - 小说章节
12. **user_novels** - 用户书架
13. **app_versions** - App版本管理
14. **app_configs** - App配置

完整SQL脚本见 `supabase/migration_complete.sql`

## 📱 界面预览

### 首页
- 小说入口卡片
- 功能快捷入口（消费/心情/体重/笔记）
- 本月统计概览

### 功能页
- 生活记录功能列表
- 简洁的卡片式布局

### 我的
- 用户信息管理
- 数据同步设置
- 应用设置

## 📝 开发计划

- [x] 项目架构搭建
- [x] 本地存储实现
- [x] Supabase集成
- [x] 首页UI
- [x] 生活记录功能（消费/心情/体重/笔记）
- [x] 收藏夹功能
- [x] 习惯打卡功能
- [x] 提醒事项功能
- [x] 小说阅读器基础版
- [x] 云端同步功能
- [ ] 小说API接入
- [ ] 数据导出功能
- [ ] 主题切换
- [ ] 通知提醒

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

---

Made with ❤️ by 纯享团队
