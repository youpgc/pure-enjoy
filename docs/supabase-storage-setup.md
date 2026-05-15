# Supabase Storage 配置说明

本文档说明如何配置 Supabase Storage 以支持 APK 自动构建和发布系统。

## 目录

1. [创建存储桶](#1-创建存储桶)
2. [配置存储桶权限](#2-配置存储桶权限)
3. [设置 GitHub Secrets](#3-设置-github-secrets)
4. [数据库配置](#4-数据库配置)
5. [验证配置](#5-验证配置)

---

## 1. 创建存储桶

### 方法 1: 使用 Supabase Dashboard (推荐)

1. 登录 [Supabase Dashboard](https://app.supabase.com)
2. 选择你的项目
3. 点击左侧菜单 **Storage**
4. 点击 **New bucket** 按钮
5. 填写信息:
   - **Name**: `apk-releases`
   - **Public bucket**: 勾选 (允许公开访问)
   - **File size limit**: `209715200` (200MB)
   - **Allowed MIME types**: `application/vnd.android.package-archive`
6. 点击 **Save**

### 方法 2: 使用 Supabase CLI

```bash
# 登录 Supabase
supabase login

# 链接到你的项目
supabase link --project-ref <your-project-id>

# 创建存储桶
supabase storage create apk-releases
```

### 方法 3: 使用 cURL

```bash
curl -X POST "https://<your-project-id>.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer <your-service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "apk-releases",
    "name": "apk-releases",
    "public": true,
    "file_size_limit": 209715200,
    "allowed_mime_types": ["application/vnd.android.package-archive"]
  }'
```

---

## 2. 配置存储桶权限

### 2.1 存储桶访问策略

在 Supabase Dashboard 中:

1. 进入 **Storage** > **Policies**
2. 选择 `apk-releases` 存储桶
3. 添加以下策略:

#### 策略 1: 允许公开读取

- **Name**: `Allow public read access`
- **Allowed operation**: `SELECT`
- **Target**: `apk-releases`
- **Policy definition**:

```sql
(bucket_id = 'apk-releases')
```

#### 策略 2: 允许服务角色上传 (GitHub Actions)

- **Name**: `Allow service role uploads`
- **Allowed operation**: `INSERT`
- **Target**: `apk-releases`
- **Policy definition**:

```sql
(bucket_id = 'apk-releases' AND auth.role() = 'service_role')
```

#### 策略 3: 允许管理员删除

- **Name**: `Allow admin deletes`
- **Allowed operation**: `DELETE`
- **Target**: `apk-releases`
- **Policy definition**:

```sql
(bucket_id = 'apk-releases' AND auth.uid() IN (
  SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'admin'
))
```

### 2.2 使用 SQL 配置 (可选)

```sql
-- 启用存储桶的 RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 允许公开读取
CREATE POLICY "Allow public read access" ON storage.objects
    FOR SELECT
    USING (bucket_id = 'apk-releases');

-- 允许服务角色上传
CREATE POLICY "Allow service role uploads" ON storage.objects
    FOR INSERT
    TO service_role
    WITH CHECK (bucket_id = 'apk-releases');

-- 允许服务角色更新
CREATE POLICY "Allow service role updates" ON storage.objects
    FOR UPDATE
    TO service_role
    USING (bucket_id = 'apk-releases');

-- 允许管理员删除
CREATE POLICY "Allow admin deletes" ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'apk-releases' AND
        auth.uid() IN (
            SELECT id FROM auth.users
            WHERE raw_user_meta_data->>'role' = 'admin'
        )
    );
```

---

## 3. 设置 GitHub Secrets

在 GitHub 仓库中设置以下 Secrets:

### 3.1 获取 Supabase 凭证

1. 进入 [Supabase Dashboard](https://app.supabase.com)
2. 选择你的项目
3. 点击 **Settings** > **API**
4. 复制以下信息:
   - **Project URL**: `https://<project-id>.supabase.co`
   - **Project API keys**:
     - `anon` (公开密钥)
     - `service_role` (服务角色密钥 - **保密!**)

### 3.2 获取 Supabase Access Token

1. 进入 [Supabase Dashboard](https://app.supabase.com) > **Account** > **Access Tokens**
2. 点击 **New access token**
3. 输入名称如 "GitHub Actions"
4. 复制生成的 token

### 3.3 在 GitHub 中设置 Secrets

1. 进入 GitHub 仓库
2. 点击 **Settings** > **Secrets and variables** > **Actions**
3. 点击 **New repository secret**
4. 添加以下 secrets:

| Secret Name | Value | 说明 |
|------------|-------|------|
| `SUPABASE_PROJECT_ID` | `your-project-id` | Supabase 项目 ID |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbG...` | Service Role Key |
| `SUPABASE_ACCESS_TOKEN` | `sbp_...` | Supabase CLI Access Token |

---

## 4. 数据库配置

### 4.1 执行 SQL 脚本

在 Supabase Dashboard 中:

1. 点击 **SQL Editor**
2. 新建查询
3. 复制并执行 `/workspace/pure-enjoy/supabase/storage_setup.sql` 中的内容

或直接运行:

```bash
# 使用 Supabase CLI
supabase db execute --file supabase/storage_setup.sql
```

### 4.2 验证表结构

执行以下查询验证表是否创建成功:

```sql
-- 检查 app_versions 表
SELECT * FROM app_versions LIMIT 1;

-- 检查 build_statuses 表
SELECT * FROM build_statuses LIMIT 1;

-- 检查函数
SELECT * FROM get_latest_version('android');
```

---

## 5. 验证配置

### 5.1 测试存储桶访问

```bash
# 测试公开读取
curl "https://<your-project-id>.supabase.co/storage/v1/object/public/apk-releases/test.txt"

# 测试上传 (需要 service_role key)
curl -X POST "https://<your-project-id>.supabase.co/storage/v1/object/apk-releases/test.txt" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: text/plain" \
  -d "Test content"
```

### 5.2 测试 GitHub Actions

1. 推送代码到 `main` 或 `develop` 分支
2. 或手动触发工作流:
   - 进入 GitHub 仓库
   - 点击 **Actions** > **Build APK and Upload to Supabase**
   - 点击 **Run workflow**
   - 输入版本号和构建号
   - 点击 **Run workflow**

### 5.3 测试手动上传脚本

```bash
# 设置环境变量
export SUPABASE_URL="https://<your-project-id>.supabase.co"
export SUPABASE_SERVICE_KEY="<your-service-role-key>"

# 运行上传脚本
./scripts/upload_apk.sh \
  -f build/app/outputs/apk/release/app-release.apk \
  -v 1.0.0 \
  -b 1 \
  -n "测试版本"
```

---

## 6. 故障排除

### 6.1 上传失败

**问题**: `403 Forbidden` 或 `401 Unauthorized`

**解决方案**:
1. 检查 `SUPABASE_SERVICE_ROLE_KEY` 是否正确
2. 检查存储桶权限策略是否正确配置
3. 验证存储桶是否存在且为公开

### 6.2 数据库插入失败

**问题**: `permission denied for table app_versions`

**解决方案**:
1. 检查 RLS 策略是否正确配置
2. 确认使用的是 `service_role` key 而非 `anon` key
3. 执行 SQL 脚本中的权限授予命令

### 6.3 构建失败

**问题**: GitHub Actions 构建失败

**解决方案**:
1. 检查 Secrets 是否正确设置
2. 查看 Actions 日志获取详细错误信息
3. 确保 Flutter 版本与项目兼容

---

## 7. 安全建议

1. **保护 Service Role Key**: 永远不要将 `SUPABASE_SERVICE_ROLE_KEY` 提交到代码仓库或泄露
2. **限制文件大小**: 设置合理的文件大小限制 (建议 200MB)
3. **启用 RLS**: 始终启用 Row Level Security
4. **定期轮换密钥**: 定期更新 GitHub Secrets 中的密钥
5. **监控访问日志**: 定期检查 Supabase 的访问日志

---

## 8. 相关文件

- `.github/workflows/build_apk.yml` - GitHub Actions 工作流
- `scripts/upload_apk.sh` - 手动上传脚本
- `supabase/storage_setup.sql` - 数据库配置 SQL
- `admin/src/pages/VersionManagement.tsx` - 后台版本管理页面
