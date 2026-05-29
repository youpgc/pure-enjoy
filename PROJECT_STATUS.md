# 纯享 App - 项目状态文档

> 最后更新: 2026-05-29
> 版本: 1.7.9+31

---

## 📊 项目概览

| 项目 | 状态 |
|-----|------|
| **App 端** | ✅ 活跃开发中 |
| **管理后台** | ✅ 已部署 |
| **数据库** | ✅ 三端对齐完成 |
| **API 接口** | ✅ 400 错误已修复 |

---

## ✅ 已完成功能

### 📖 小说模块
- [x] 小说列表浏览
- [x] 小说详情页
- [x] 阅读器（字体/背景调节）
- [x] 书架管理（user_novels 表）
- [x] 阅读进度保存

### ✍️ 生活记录模块
- [x] **消费记录** - 记账、分类统计
- [x] **心情日记** - 表情选择、每日记录
- [x] **体重记录** - BMI 计算、趋势追踪
- [x] **笔记本** - 富文本编辑、置顶功能
- [x] **收藏夹** - URL 收藏、标签管理
- [x] **习惯打卡** - 连续打卡统计、 streak 记录
- [x] **提醒事项** - 优先级、完成状态

### 🔐 用户系统
- [x] 邮箱注册/登录
- [x] 密码 SHA-256 加密
- [x] 用户信息编辑（昵称、头像）
- [x] 云端数据同步
- [x] 本地离线使用

### ⚙️ 系统功能
- [x] 版本检查与更新
- [x] APK 下载与安装
- [x] 主题切换（亮色/暗色）
- [x] 数据同步（双向）

---

## 🔧 技术架构

### 前端 (Flutter)
```
lib/
├── core/               # 核心模块
│   ├── constants/      # 常量配置
│   ├── theme/          # 主题管理
│   ├── utils/          # 工具类
│   └── widgets/        # 通用组件
├── features/           # 功能模块
│   ├── auth/           # 认证
│   ├── home/           # 首页
│   ├── life/           # 生活记录
│   │   ├── models/     # 数据模型
│   │   └── screens/    # 页面
│   ├── novel/          # 小说
│   └── profile/        # 个人中心
└── services/           # 服务层
    ├── database_service.dart
    ├── storage_service.dart
    ├── supabase_service.dart
    ├── sync_service.dart
    └── version_check_service.dart
```

### 后端 (Supabase)
- **认证**: 自定义 users 表 + SHA-256 密码
- **数据库**: PostgreSQL 14 张业务表
- **存储**: 头像/图片存储桶

### 管理后台 (React + Vite)
- 部署: GitHub Pages
- 地址: https://youpgc.github.io/pure-enjoy-admin/

---

## 📋 数据库表结构

| 表名 | 用途 | 状态 |
|-----|------|------|
| users | 用户表 | ✅ |
| expenses | 消费记录 | ✅ |
| mood_diaries | 心情日记 | ✅ |
| weight_records | 体重记录 | ✅ |
| notes | 笔记 | ✅ |
| user_favorites | 收藏夹 | ✅ |
| user_reminders | 提醒事项 | ✅ |
| user_habits | 习惯打卡 | ✅ |
| habit_checkins | 打卡记录 | ✅ |
| novels | 小说表 | ✅ |
| novel_chapters | 小说章节 | ✅ |
| user_novels | 用户书架 | ✅ |
| app_versions | 版本管理 | ✅ |
| app_configs | App 配置 | ✅ |
| admin_users | 管理员 | ✅ |
| operation_logs | 操作日志 | ✅ |
| error_logs | 错误日志 | ✅ |
| role_permissions | 角色权限 | ✅ |

---

## 🐛 已知问题

### 已修复
- [x] API 400 错误（字段名不匹配）
- [x] 三端字段对齐
- [x] 管理端部署问题

### 待解决
- [ ] 小说 API 接入（爬虫数据）
- [ ] 本地通知功能（兼容性问题已禁用）
- [ ] 数据导出功能

---

## 📝 开发计划

### 高优先级
- [ ] 小说内容爬虫接入
- [ ] 章节内容自动抓取
- [ ] 小说搜索功能

### 中优先级
- [ ] 数据导出（Excel/JSON）
- [ ] 数据导入
- [ ] 本地通知提醒

### 低优先级
- [ ] 更多主题配色
- [ ] 字体自定义
- [ ] 阅读统计

---

## 🔗 相关链接

| 资源 | 链接 |
|-----|------|
| App GitHub | https://github.com/youpgc/pure-enjoy |
| App Gitee | https://gitee.com/YouPgC/pure-enjoy |
| Admin GitHub | https://github.com/youpgc/pure-enjoy-admin |
| Admin Gitee | https://gitee.com/YouPgC/pure-enploy-admin |
| Admin 部署 | https://youpgc.github.io/pure-enjoy-admin/ |

---

## 🛠 开发环境

```yaml
Flutter: >=3.0.0 <4.0.0
Dart: >=3.0.0

主要依赖:
- provider: ^6.1.1 (状态管理)
- http: ^1.1.0 (Supabase REST API)
- shared_preferences: ^2.2.2 (本地存储)
- intl: ^0.19.0 (国际化)
- crypto: ^3.0.3 (密码加密)
- image_picker: ^1.0.7 (头像上传)
```

---

## 📦 构建配置

### Android
- 包名: `com.pureenjoy.app`
- 版本: `1.7.9+31`
- 签名: 已配置 release.keystore

### CI/CD
- GitHub Actions: `.github/workflows/build_apk.yml`
- 自动构建 APK
- 自动部署管理端

---

## 💡 注意事项

1. **Supabase 配置**: 修改 `lib/config.dart`
2. **数据库迁移**: 使用 `supabase/migration_complete.sql`
3. **管理端登录**: 使用 admin_users 表
4. **图片上传**: 需要配置 avatars/images 存储桶

---

*Made with ❤️ by 纯享团队*
