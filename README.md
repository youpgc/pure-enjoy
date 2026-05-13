# 纯享 (Pure Enjoy)

一个免费的小说阅读与生活记录App，无广告，简洁优雅。

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
cd pure_enjoy
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
pure_enjoy/
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
│   │   │   ├── data/       # 数据模型
│   │   │   └── presentation/ # UI页面
│   │   ├── novel/          # 小说模块
│   │   └── profile/        # 个人中心
│   ├── services/           # 服务层
│   │   ├── storage_service.dart    # 本地存储
│   │   └── supabase_service.dart   # 云端服务
│   └── main.dart           # 应用入口
├── assets/                 # 静态资源
├── pubspec.yaml           # 依赖配置
└── README.md
```

## 🛠 技术栈

- **Flutter** - 跨平台UI框架
- **Riverpod** - 状态管理
- **Hive** - 本地数据存储
- **Supabase** - 云端服务（认证+数据库）
- **intl** - 国际化与日期格式化

## 🔧 配置说明

### Supabase 配置

项目已配置好Supabase，如需修改，请编辑：

```dart
// lib/core/constants/app_constants.dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 数据库表结构

需要在Supabase中创建以下表：

1. **expenses** - 消费记录
2. **mood_diaries** - 心情日记
3. **weight_records** - 体重记录
4. **notes** - 笔记
5. **novels** - 小说书架

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
- [x] 小说阅读器基础版
- [ ] 小说API接入
- [ ] 云端同步功能
- [ ] 数据导出功能
- [ ] 主题切换
- [ ] 通知提醒

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

---

Made with ❤️ by 纯享团队
