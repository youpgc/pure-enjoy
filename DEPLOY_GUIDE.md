# 纯享项目部署指南

> 版本: v2.0
> 日期: 2026-06-19
> 更新内容: 迁移 APK 存储从 Supabase Storage 到 GitHub Releases，升级 Flutter 3.44.2 + Android 构建配置

---

## 一、部署流程概述

每次完成任务后，执行以下步骤：

1. **提交代码** → GitHub & Gitee
2. **构建部署** → 管理后台自动部署到 GitHub Pages
3. **构建 APK** → App 端自动打包并上传到 GitHub Releases
4. **汇报结果** → 按标准格式输出构建状态

---

## 二、项目结构

| 项目 | 本地路径 | GitHub 仓库 | Gitee 仓库 | 分支 |
|------|---------|-------------|-----------|------|
| 纯享App | `/workspace/pure-enjoy` | `youpgc/pure-enjoy` | `YouPgC/pure-enjoy` | `master` |
| 管理后台 | `/workspace/pure-enjoy-admin` | `youpgc/pure-enjoy-admin` | `YouPgC/pure-enjoy-admin` | `main` |

---

## 三、环境配置

### GitHub Token

```bash
export GITHUB_TOKEN="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"
export GH_TOKEN="$GITHUB_TOKEN"
```

**Token 权限要求：** `repo`、`workflow`、`read:org`

> 注意：当前 Token 已内嵌在两个仓库的 git remote URL 中，无需额外配置即可 push。

### Flutter SDK（本地分析）

```bash
# Flutter 已安装在 /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# 验证安装
flutter --version
```

**用途：** 本地运行 `flutter analyze` 提前发现编译错误，避免提交后 CI 构建失败。

### Gitee Token

```bash
export GITEE_TOKEN="f12d23f9aa08cb5f8792e4133202074e"
```

**Gitee 仓库地址：**
- 管理后台：`https://gitee.com/YouPgC/pure-enjoy-admin`
- App端：`https://gitee.com/YouPgC/pure-enjoy`

### Git Remote 配置（已完成）

```bash
# App端 - GitHub（已含 Token）
cd /workspace/pure-enjoy
git remote -v
# origin -> https://ghp_xxx@github.com/youpgc/pure-enjoy.git

# App端 - Gitee（需手动添加）
git remote add gitee "https://youpgc:${GITEE_TOKEN}@gitee.com/YouPgC/pure-enjoy.git"

# 管理后台 - GitHub（已含 Token）
cd /workspace/pure-enjoy-admin
git remote -v
# origin -> https://ghp_xxx@github.com/youpgc/pure-enjoy-admin.git

# 管理后台 - Gitee（需手动添加）
git remote add gitee "https://youpgc:${GITEE_TOKEN}@gitee.com/YouPgC/pure-enjoy-admin.git"
```

---

## 四、快速部署命令

### 管理后台部署

```bash
cd /workspace/pure-enjoy-admin

# 提交并推送到 GitHub（自动触发 GitHub Pages 部署）
git add -A
git commit -m "feat: xxx功能"
git push origin main

# 同步到 Gitee
git push gitee main
```

**自动构建流程：**
- 触发条件：`main` 分支 push
- 构建工具：Vite 6 + Node.js 20
- 部署目标：GitHub Pages
- 部署地址：`https://youpgc.github.io/pure-enjoy-admin/`

### App 端代码同步

```bash
cd /workspace/pure-enjoy

# 步骤1：本地静态分析（强制，不允许跳过）
flutter pub get
flutter analyze
# 如果有 error 或 warning，必须先修复再提交

# 步骤2：提交并推送到 GitHub（自动触发 APK 构建）
git add -A
git commit -m "feat: xxx功能"
git push origin master

# 同步到 Gitee
git push gitee master
```

**自动构建流程：**
- 触发条件：`master`/`main`/`develop` 分支 push、`v*` 标签、手动触发
- 构建环境：Flutter 3.44.2 + Java 17 (Temurin) + Gradle 8.11.1 + AGP 8.9.1
- 构建步骤：获取依赖 → 代码生成 → 测试 → 版本号自动迭代 → 构建 APK → 上传 GitHub Releases → 写入数据库版本记录 → 清理旧 GitHub Releases（保留最新 10 个）
- 版本号自动管理：每次 push 自动递增 patch 版本号和构建号（`chore:` 开头的提交或上次构建失败时跳过递增）
- APK 命名：`pure-enjoy-v{version}-build{build_number}.apk`

---

## 五、构建失败排查流程

### 5.1 获取构建日志（推荐方式）

使用 GitHub Token 通过 API 获取构建状态和日志，无需登录网页：

```bash
export GITHUB_TOKEN="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"

# 步骤1：查看最新构建状态（获取 run_id）
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/youpgc/pure-enjoy/actions/runs?per_page=5" | \
  python3 -c "import sys,json; data=json.load(sys.stdin); [print(f\"{r['run_number']} | {r['head_commit']['message'][:40]} | {r['conclusion'] or r['status']}\") for r in data.get('workflow_runs',[])]"

# 步骤2：获取构建的 job ID（替换 {RUN_ID}）
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/youpgc/pure-enjoy/actions/runs/{RUN_ID}/jobs" | \
  python3 -c "import sys,json; data=json.load(sys.stdin); [print(f\"{j['name']} | {j['conclusion']} | {j['id']}\") for j in data.get('jobs',[])]"

# 步骤3：获取错误日志（替换 {JOB_ID}）
# 方式A：只提取 Error 行（推荐，快速定位问题）
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -L "https://api.github.com/repos/youpgc/pure-enjoy/actions/jobs/{JOB_ID}/logs" 2>/dev/null | \
  grep -E "Error:" | head -50

# 方式B：提取所有 error/fail 相关行
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -L "https://api.github.com/repos/youpgc/pure-enjoy/actions/jobs/{JOB_ID}/logs" 2>/dev/null | \
  grep -i "error\|fail" | head -50

# 方式C：查看特定错误上下文（如 Database 错误）
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -L "https://api.github.com/repos/youpgc/pure-enjoy/actions/jobs/{JOB_ID}/logs" 2>/dev/null | \
  grep -A5 -B5 "Database operation failed" | head -30
```

**日志获取技巧：**
- 构建日志是 gzip 压缩的，curl 会自动处理（无需手动 gunzip）
- 如果 `grep -E "Error:"` 无输出，说明编译阶段通过，错误在后续步骤（上传/数据库）
- 使用 `grep -i "error\|fail"` 可以捕获更多类型的错误信息
- 对于数据库错误（HTTP 400/500），使用 `grep -A5 -B5 "Database"` 查看完整响应体

### 5.2 自动监听构建状态

推送代码后，使用循环命令自动监听构建状态：

```bash
export GITHUB_TOKEN="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"

# 自动轮询构建状态（每50秒检查一次，共12次，约10分钟）
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  echo "=== 检查 #$i ==="
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/youpgc/pure-enjoy/actions/runs?per_page=1" | \
    python3 -c "import sys,json; data=json.load(sys.stdin); r=data.get('workflow_runs',[{}])[0]; print(f'Run {r.get(\"run_number\",\"?\")}: {r.get(\"conclusion\") or r.get(\"status\",\"unknown\")}')"
  sleep 50
done
```

### 5.3 修复后重新推送

**关键：修复构建失败的代码后重新推送时，构建号不会递增。**

CI 会自动检测上次构建是否失败，如果失败则跳过版本号递增，直接使用当前版本构建。

```bash
cd /workspace/pure-enjoy

# 修复代码
git add -A
git commit -m "fix: 修复构建错误"
git pull --rebase && git push origin master

# 监听新构建状态
for i in 1 2 3 4 5 6 7 8; do
  echo "=== 检查 #$i ==="
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/youpgc/pure-enjoy/actions/runs?per_page=1" | \
    python3 -c "import sys,json; data=json.load(sys.stdin); r=data.get('workflow_runs',[{}])[0]; print(f'Run {r.get(\"run_number\",\"?\")}: {r.get(\"conclusion\") or r.get(\"status\",\"unknown\")}')"
  sleep 50
done
```

---

## 六、GitHub Actions 配置详情

### 管理后台：deploy.yml

**文件路径：** `/workspace/pure-enjoy-admin/.github/workflows/deploy.yml`

| 配置项 | 值 |
|-------|---|
| 触发条件 | `main` 分支 push、手动触发 |
| 运行环境 | `ubuntu-latest` |
| Node.js 版本 | 20 |
| 超时时间 | 构建 10 分钟，部署 5 分钟 |
| 部署方式 | `actions/deploy-pages@v4`（GitHub 官方 Pages 部署） |
| 并发控制 | 同一 group 只允许一个构建，自动取消进行中的旧构建 |

### App 端：build_apk.yml

**文件路径：** `/workspace/pure-enjoy/.github/workflows/build_apk.yml`

| 配置项 | 值 |
|-------|---|
| 工作流名称 | `Build APK and Upload to GitHub Releases` |
| 触发条件 | `master`/`main`/`develop` 分支 push、`v*` 标签、手动触发 |
| 运行环境 | `ubuntu-latest` |
| Flutter 版本 | 3.44.2 (stable channel) |
| Java 版本 | 17 (Temurin) |
| Gradle 版本 | 8.11.1 |
| Android Gradle Plugin | 8.9.1 |
| Kotlin 版本 | 2.0.20 |
| compileSdk / targetSdk | 36 |
| minSdk | 21 |
| 构建产物 | Release APK |
| APK 存储 | **GitHub Releases**（无大小限制） |
| 版本记录 | Supabase `app_versions` 表（仅存储元数据，apk_url 指向 GitHub Releases） |
| 旧版清理 | 自动删除超过 10 个的旧 GitHub Releases |
| 并发控制 | 同一分支只允许一个构建 |
| 构建号保护 | 上次构建失败时，重新推送不递增构建号 |
| 代码压缩 | `minifyEnabled true` + `shrinkResources true` + R8 |
| ABI 过滤 | `arm64-v8a`, `armeabi-v7a`（移除 x86/x86_64） |
| Dart 优化 | `--obfuscate` + `--tree-shake-icons` + `--split-debug-info` |

**所需 Secrets：**
- `GITHUB_TOKEN`（用于创建 GitHub Release 和上传 APK）
- `SUPABASE_PROJECT_ID`（用于写入版本记录数据库）
- `SUPABASE_SERVICE_ROLE_KEY`（用于写入版本记录数据库）

**数据流向：**
```
构建 APK → GitHub Releases（APK 文件存储）
         → Supabase app_versions（版本元数据记录：版本号、下载 URL、大小、SHA256 等）
         → Supabase 旧版本标记 revoked
```

---

## 七、构建汇报格式

每次自动化构建完成后，按以下格式汇报：

```markdown
## 构建结果

| 项目 | 状态 | 版本 | 部署地址 |
|------|------|------|----------|
| 管理后台 | 构建成功/失败 | - | `https://youpgc.github.io/pure-enjoy-admin/` |
| App端 | 构建成功/失败 | v1.9.222+268 | APK 已上传至 GitHub Releases |

---

## 本次修改汇总

### 管理后台 `pure-enjoy-admin`
- `文件路径` — 修改说明

### App端 `pure-enjoy`
- `文件路径` — 修改说明
```

---

## 八、版本号管理

### App 版本号规则

**文件：** `/workspace/pure-enjoy/pubspec.yaml`

```yaml
version: 1.9.222+268
# 格式: 主版本.次版本.修订号+构建号
```

- **主版本号**：重大功能更新
- **次版本号**：新功能添加
- **修订号**：Bug 修复（每次 push 自动递增，构建失败修复时跳过）
- **构建号**：每次构建自动递增（构建失败修复时跳过）

> CI 会自动管理版本号，通常不需要手动修改。
> 构建失败修复后重新推送时，版本号不会递增。

---

## 九、仓库地址

### 管理后台 (pure-enjoy-admin)

| 平台 | 地址 |
|------|------|
| GitHub | `https://github.com/youpgc/pure-enjoy-admin` |
| Gitee | `https://gitee.com/YouPgC/pure-enjoy-admin` |
| 部署地址 | `https://youpgc.github.io/pure-enjoy-admin/` |

### App 端 (pure-enjoy)

| 平台 | 地址 |
|------|------|
| GitHub | `https://github.com/youpgc/pure-enjoy` |
| Gitee | `https://gitee.com/YouPgC/pure-enjoy` |
| APK 下载 | GitHub Releases（`https://github.com/youpgc/pure-enjoy/releases`） |

---

## 十、Supabase 数据库

### 连接信息

- **项目 ID：** `mhdrbjpqmzswswoazwjg`
- **URL：** `https://mhdrbjpqmzswswoazwjg.supabase.co`
- **认证方式：** 自定义用户表（绕过 Supabase Auth），SHA-256 密码哈希
- **用户识别：** 通过 `x-user-id` HTTP header

### Service Role Key

```bash
export SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1oZHJianBxbXpzd3N3b2F6d2pnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODYyMDIxMywiZXhwIjoyMDk0MTk2MjEzfQ.N9av5Q_bmFu2X4_8kM9TCrSjh0x0u856PLkwqWkKK5w"
```

**用途：** 用于 AI 助手直接操作 Supabase 数据库（执行 SQL、查询数据等），具有超级管理员权限，绕过 RLS 策略。

**注意：** Supabase Storage 不再用于存储 APK 文件（50MB 大小限制）。仅保留 `app_versions` 表用于版本元数据管理。

---

## 十一、常见问题

### Q1: 管理后台构建失败

检查：
- `package.json` 依赖是否完整（`npm ci` 能否成功）
- `vite.config.ts` 中 `base` 配置是否为 `/pure-enjoy-admin/`
- TypeScript 编译是否有错误

### Q2: App 端 APK 构建失败

排查步骤：
1. 使用 GitHub Token 获取构建日志（见第 5.1 节）
2. 定位错误原因（Dart 编译错误 / CI 脚本错误 / 依赖问题）
3. 修复代码后重新推送（构建号不会递增）
4. 监听新构建状态

常见原因：
- Flutter 版本是否为 3.44.2
- `pubspec.lock` 是否存在（CI 缓存依赖）
- `GeneratedPluginRegistrant.java` 是否在 git 跟踪中
- Android 构建配置：AGP 8.9.1 / Kotlin 2.0.20 / Gradle 8.11.1 / compileSdk 36
- ProGuard 规则是否完整（R8 压缩失败）

### Q3: Gitee 推送失败

检查：
- Gitee remote 是否已添加：`git remote -v`
- Token 是否过期
- 网络连接是否正常

### Q4: 管理后台页面报 `too few arguments for format()`

原因：Supabase 数据库中的 RPC 函数有 bug。
修复：在 Supabase SQL Editor 中执行 `sql/create_rpc_functions.sql`。

### Q5: 管理后台错误日志页面无数据

原因：`error_logs` 等表启用了 RLS 但没有创建策略。
修复：在 Supabase SQL Editor 中执行 `sql/fix_logs_rls.sql`。

### Q6: GitHub Token 失效

检查：
- Token 是否过期（GitHub Settings > Developer settings > Personal access tokens）
- 环境变量是否正确设置：`echo $GITHUB_TOKEN`

### Q7: APK 体积超过 50MB（Supabase 限制）

**已解决：** 自 v2.0 起，APK 已迁移到 GitHub Releases 存储，不再受 Supabase 50MB 限制。

如果 APK 体积异常增大（>60MB），检查：
- 是否意外引入了大型依赖
- `assets/images/` 中是否有未使用的大文件
- `pubspec.yaml` 的 `assets` 是否精确引用（避免整目录打包）

---

## 十二、部署检查清单

**部署前确认：**

- [ ] 代码已提交到本地仓库
- [ ] TypeScript 编译无错误（管理后台）
- [ ] `flutter analyze` 无 error 和 warning（App 端）——**不允许跳过**
- [ ] 提交信息清晰明确（遵循 Conventional Commits）

**部署后确认：**

- [ ] GitHub Actions 构建成功
- [ ] 管理后台可正常访问：`https://youpgc.github.io/pure-enjoy-admin/`
- [ ] Gitee 代码已同步
- [ ] 按标准格式汇报构建结果

---

*本文档由开发助手自动生成，最后更新：2026-06-19*

---

# 附录：历史版本（已作废）

## v1.6（已作废）

> 日期: 2026-06-18
> 作废原因: Flutter 3.44.2 升级后 APK 体积超过 Supabase Storage 50MB 限制，已迁移到 GitHub Releases

### v1.6 与 v2.0 的主要差异

| 项目 | v1.6（作废） | v2.0（当前） |
|------|-------------|-------------|
| Flutter 版本 | 3.24.0 | 3.44.2 |
| Gradle 版本 | 8.4 | 8.11.1 |
| AGP 版本 | 8.1.0 | 8.9.1 |
| Kotlin 版本 | 1.9.0 | 2.0.20 |
| compileSdk | 34 | 36 |
| APK 存储 | Supabase Storage | GitHub Releases |
| 旧版清理 | Supabase Storage（保留 5 个） | GitHub Releases（保留 10 个） |
| 所需 Secrets | SUPABASE_ACCESS_TOKEN, SUPABASE_PROJECT_ID, SUPABASE_SERVICE_ROLE_KEY, GITHUB_TOKEN | GITHUB_TOKEN, SUPABASE_PROJECT_ID, SUPABASE_SERVICE_ROLE_KEY |

### v1.6 的 App 端构建流程（已作废，仅存档）

```
获取依赖 → 代码生成 → 测试 → 版本号自动迭代 → 构建 APK → 上传 Supabase Storage → 写入数据库版本记录 → 清理旧 APK（保留最新5个）
```

### v1.6 的 build_apk.yml 配置（已作废，仅存档）

| 配置项 | v1.6 值 |
|-------|---------|
| Flutter 版本 | 3.24.0 (stable channel) |
| Java 版本 | 17 (Temurin) |
| 构建产物 | Release APK |
| APK 上传 | Supabase Storage (`apk-releases` 桶) |
| 版本记录 | Supabase `app_versions` 表 |
| 旧版清理 | 自动删除超过 5 个的旧 APK 并标记数据库记录为 `superseded` |
| 并发控制 | 同一分支只允许一个构建 |
| 构建号保护 | 上次构建失败时，重新推送不递增构建号 |

### v1.6 常见问题（已作废，仅存档）

**Q: APK 上传失败 Payload too large (413)**
原因：Supabase Storage 单文件大小限制约 50MB，Flutter 3.44.2 引擎体积增大后 APK 超过限制。
解决：升级到 v2.0，迁移到 GitHub Releases。
