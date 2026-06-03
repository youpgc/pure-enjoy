-- 修复 error_logs 表 RLS 策略
-- 允许匿名用户插入错误日志（用于前端错误上报）

-- 先禁用 RLS 以修改策略
ALTER TABLE IF EXISTS error_logs DISABLE ROW LEVEL SECURITY;

-- 删除现有的所有策略
DROP POLICY IF EXISTS "允许匿名插入错误日志" ON error_logs;
DROP POLICY IF EXISTS "允许认证用户查看错误日志" ON error_logs;
DROP POLICY IF EXISTS "允许服务角色管理错误日志" ON error_logs;
DROP POLICY IF EXISTS "Enable all access for service role" ON error_logs;
DROP POLICY IF EXISTS "Enable insert for anonymous users" ON error_logs;

-- 重新启用 RLS
ALTER TABLE IF EXISTS error_logs ENABLE ROW LEVEL SECURITY;

-- 创建策略：允许任何人（包括匿名用户）插入错误日志
CREATE POLICY "允许匿名插入错误日志" ON error_logs
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- 创建策略：允许认证用户查看错误日志
CREATE POLICY "允许认证用户查看错误日志" ON error_logs
    FOR SELECT
    TO authenticated
    USING (true);

-- 创建策略：允许服务角色完全管理错误日志
CREATE POLICY "允许服务角色管理错误日志" ON error_logs
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 确保表对所有角色可访问
GRANT ALL ON error_logs TO service_role;
GRANT INSERT ON error_logs TO anon;
GRANT INSERT, SELECT ON error_logs TO authenticated;

COMMENT ON TABLE error_logs IS '错误日志表 - 允许匿名插入用于前端错误上报';
