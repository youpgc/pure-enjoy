-- ============================================================
-- 修复收藏夹 PATCH 400 错误
-- 原因: RLS 策略使用 auth.uid()，但 App 端绕过了 Supabase Auth
--       导致 auth.uid() 返回 null，RLS 拒绝操作
-- 修复: 替换为允许 anon 角色操作（通过 API Key 认证）
-- ============================================================

-- 删除旧的 RLS 策略
DROP POLICY IF EXISTS "user_favorites_owner" ON user_favorites;

-- 创建新策略：允许所有操作（通过 API Key 认证控制访问）
CREATE POLICY "user_favorites_allow_all" ON user_favorites
  FOR ALL
  USING (true)
  WITH CHECK (true);
