-- =============================================================================
-- Supabase Storage 和版本管理配置
-- 用于 APK 自动构建和发布系统
-- =============================================================================

-- =============================================================================
-- 1. 创建存储桶 (Storage Bucket)
-- =============================================================================

-- 注意: 存储桶需要通过 Supabase Dashboard 或 CLI 创建
-- SQL 中无法直接创建存储桶，以下是等效的 CLI 命令:

/*
-- 使用 Supabase CLI 创建存储桶:
supabase storage create apk-releases

-- 或者使用 curl:
curl -X POST "https://<project-id>.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "apk-releases",
    "name": "apk-releases",
    "public": true,
    "file_size_limit": 209715200,
    "allowed_mime_types": ["application/vnd.android.package-archive"]
  }'
*/

-- =============================================================================
-- 2. 创建版本表 (如果尚未创建)
-- =============================================================================

-- 应用版本表
CREATE TABLE IF NOT EXISTS app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(50) NOT NULL,
    build_number INTEGER NOT NULL,
    download_url TEXT NOT NULL,
    file_size BIGINT,
    checksum VARCHAR(64),
    release_notes TEXT,
    is_force_update BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    platform VARCHAR(20) DEFAULT 'android',
    file_name VARCHAR(255),
    created_by VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 构建状态表
CREATE TABLE IF NOT EXISTS build_statuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(50) NOT NULL,
    build_number INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, building, success, failed
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    logs TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- 3. 创建索引
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_app_versions_version ON app_versions(version);
CREATE INDEX IF NOT EXISTS idx_app_versions_build_number ON app_versions(build_number);
CREATE INDEX IF NOT EXISTS idx_app_versions_is_active ON app_versions(is_active);
CREATE INDEX IF NOT EXISTS idx_app_versions_platform ON app_versions(platform);
CREATE INDEX IF NOT EXISTS idx_app_versions_created_at ON app_versions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_build_statuses_status ON build_statuses(status);
CREATE INDEX IF NOT EXISTS idx_build_statuses_started_at ON build_statuses(started_at DESC);

-- =============================================================================
-- 4. 创建触发器 (自动更新 updated_at)
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_app_versions_updated_at ON app_versions;
CREATE TRIGGER update_app_versions_updated_at
    BEFORE UPDATE ON app_versions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. 启用 RLS (Row Level Security)
-- =============================================================================

ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE build_statuses ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 6. 创建 RLS 策略
-- =============================================================================

-- app_versions 表策略

-- 允许匿名用户读取活跃版本 (用于 App 检查更新)
CREATE POLICY "Allow anonymous to read active versions" ON app_versions
    FOR SELECT
    USING (is_active = true);

-- 允许认证用户读取所有版本
CREATE POLICY "Allow authenticated to read all versions" ON app_versions
    FOR SELECT
    TO authenticated
    USING (true);

-- 允许管理员插入/更新/删除
CREATE POLICY "Allow admin to insert versions" ON app_versions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

CREATE POLICY "Allow admin to update versions" ON app_versions
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

CREATE POLICY "Allow admin to delete versions" ON app_versions
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth.users
            WHERE auth.users.id = auth.uid()
            AND auth.users.raw_user_meta_data->>'role' = 'admin'
        )
    );

-- build_statuses 表策略

-- 允许认证用户读取构建状态
CREATE POLICY "Allow authenticated to read build statuses" ON build_statuses
    FOR SELECT
    TO authenticated
    USING (true);

-- 允许服务角色插入/更新 (用于 GitHub Actions)
CREATE POLICY "Allow service role to insert build statuses" ON build_statuses
    FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "Allow service role to update build statuses" ON build_statuses
    FOR UPDATE
    TO service_role
    USING (true);

-- =============================================================================
-- 7. 创建辅助函数
-- =============================================================================

-- 获取最新版本
CREATE OR REPLACE FUNCTION get_latest_version(p_platform TEXT DEFAULT 'android')
RETURNS TABLE (
    id UUID,
    version VARCHAR,
    build_number INTEGER,
    download_url TEXT,
    release_notes TEXT,
    is_force_update BOOLEAN,
    file_size BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        av.id,
        av.version,
        av.build_number,
        av.download_url,
        av.release_notes,
        av.is_force_update,
        av.file_size
    FROM app_versions av
    WHERE av.platform = p_platform
      AND av.is_active = true
    ORDER BY av.build_number DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 检查是否需要更新
CREATE OR REPLACE FUNCTION check_update(
    p_version TEXT,
    p_build_number INTEGER,
    p_platform TEXT DEFAULT 'android'
)
RETURNS TABLE (
    has_update BOOLEAN,
    force_update BOOLEAN,
    latest_version VARCHAR,
    download_url TEXT,
    release_notes TEXT
) AS $$
DECLARE
    v_latest RECORD;
BEGIN
    SELECT * INTO v_latest FROM get_latest_version(p_platform);

    IF v_latest IS NULL THEN
        RETURN QUERY SELECT false, false, NULL::VARCHAR, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    RETURN QUERY SELECT
        v_latest.build_number > p_build_number,
        v_latest.is_force_update,
        v_latest.version,
        v_latest.download_url,
        v_latest.release_notes;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 8. 授予权限
-- =============================================================================

GRANT SELECT ON app_versions TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_versions TO authenticated;
GRANT ALL ON app_versions TO service_role;

GRANT SELECT ON build_statuses TO authenticated;
GRANT ALL ON build_statuses TO service_role;

GRANT EXECUTE ON FUNCTION get_latest_version TO anon;
GRANT EXECUTE ON FUNCTION get_latest_version TO authenticated;
GRANT EXECUTE ON FUNCTION check_update TO anon;
GRANT EXECUTE ON FUNCTION check_update TO authenticated;

-- =============================================================================
-- 9. 插入示例数据 (可选)
-- =============================================================================

/*
INSERT INTO app_versions (
    version,
    build_number,
    download_url,
    file_size,
    checksum,
    release_notes,
    is_force_update,
    is_active,
    platform,
    file_name,
    created_by
) VALUES (
    '1.0.0',
    1,
    'https://your-project.supabase.co/storage/v1/object/public/apk-releases/pure-enjoy-v1.0.0+1.apk',
    25000000,
    'a1b2c3d4e5f6...',
    '初始版本发布',
    false,
    true,
    'android',
    'pure-enjoy-v1.0.0+1.apk',
    'system'
);
*/
