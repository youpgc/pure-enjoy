-- ============================================================
-- 修复管理后台相关表的 RLS 策略
-- 问题：部分表启用了 RLS 但没有创建策略，导致管理后台无法读取数据
-- 包括：error_logs, operation_logs, app_versions, dict_types, dict_items,
--       app_configs, sensitive_word_logs, files, sensitive_words, users,
--       habits, anniversaries, point_records
-- ============================================================

-- 辅助函数（如果不存在则创建）
CREATE OR REPLACE FUNCTION get_request_user_id()
RETURNS TEXT AS $$
DECLARE
  headers_json JSON;
  jwt_claims JSON;
  result TEXT;
BEGIN
  BEGIN
    headers_json := current_setting('request.headers', true)::json;
    result := headers_json->>'x-user-id';
    IF result IS NOT NULL AND result != '' THEN
      RETURN result;
    END IF;
  EXCEPTION WHEN OTHERS THEN
  END;

  BEGIN
    jwt_claims := current_setting('request.jwt.claims', true)::json;
    result := jwt_claims->>'sub';
    IF result IS NOT NULL AND result != '' THEN
      RETURN result;
    END IF;
  EXCEPTION WHEN OTHERS THEN
  END;

  BEGIN
    result := current_setting('request.header.x-user-id', true);
    IF result IS NOT NULL AND result != '' THEN
      RETURN result;
    END IF;
  EXCEPTION WHEN OTHERS THEN
  END;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_current_user_admin()
RETURNS BOOLEAN AS $$
DECLARE
  current_user_id TEXT;
  user_role TEXT;
BEGIN
  current_user_id := get_request_user_id();
  IF current_user_id IS NULL THEN
    RETURN FALSE;
  END IF;
  SELECT role INTO user_role FROM users WHERE id = current_user_id;
  RETURN user_role IN ('admin', 'super_admin');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- 辅助函数：为指定表创建管理员 RLS 策略
-- ============================================================

CREATE OR REPLACE FUNCTION create_admin_rls_policies(p_table_name TEXT)
RETURNS TEXT AS $$
DECLARE
  r RECORD;
  table_exists BOOLEAN;
BEGIN
  -- 检查表是否存在
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = p_table_name
  ) INTO table_exists;

  IF NOT table_exists THEN
    RETURN '表 ' || p_table_name || ' 不存在，跳过';
  END IF;

  -- 启用 RLS
  EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', p_table_name);

  -- 清除旧策略
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = p_table_name LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, p_table_name);
  END LOOP;

  -- 管理员 SELECT
  EXECUTE format('CREATE POLICY %I_select_admin ON %I FOR SELECT USING (is_current_user_admin())',
    p_table_name || '_admin', p_table_name);

  -- 管理员 INSERT
  EXECUTE format('CREATE POLICY %I_insert_admin ON %I FOR INSERT WITH CHECK (is_current_user_admin())',
    p_table_name || '_admin_ins', p_table_name);

  -- 管理员 UPDATE
  EXECUTE format('CREATE POLICY %I_update_admin ON %I FOR UPDATE USING (is_current_user_admin())',
    p_table_name || '_admin_upd', p_table_name);

  -- 管理员 DELETE
  EXECUTE format('CREATE POLICY %I_delete_admin ON %I FOR DELETE USING (is_current_user_admin())',
    p_table_name || '_admin_del', p_table_name);

  -- 允许所有人 INSERT（用于错误日志上报等）
  IF p_table_name IN ('error_logs', 'operation_logs') THEN
    EXECUTE format('CREATE POLICY %I_insert_all ON %I FOR INSERT WITH CHECK (true)',
      p_table_name || '_all_ins', p_table_name);
  END IF;

  RETURN '已为表 ' || p_table_name || ' 创建管理员 RLS 策略';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 为每个表创建策略
-- ============================================================

SELECT create_admin_rls_policies('error_logs');
SELECT create_admin_rls_policies('operation_logs');
SELECT create_admin_rls_policies('app_versions');
SELECT create_admin_rls_policies('dict_types');
SELECT create_admin_rls_policies('dict_items');
SELECT create_admin_rls_policies('app_configs');
SELECT create_admin_rls_policies('sensitive_word_logs');
SELECT create_admin_rls_policies('files');
SELECT create_admin_rls_policies('sensitive_words');
SELECT create_admin_rls_policies('users');
SELECT create_admin_rls_policies('habits');
SELECT create_admin_rls_policies('anniversaries');
SELECT create_admin_rls_policies('point_records');

-- 删除辅助函数（可选，保留也可以）
-- DROP FUNCTION IF EXISTS create_admin_rls_policies(TEXT);

-- ============================================================
-- 验证
-- ============================================================

SELECT 'RLS 策略修复完成' AS status;

-- 查看所有管理后台相关表的策略
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN (
  'error_logs', 'operation_logs', 'app_versions', 'dict_types', 'dict_items',
  'app_configs', 'sensitive_word_logs', 'files', 'sensitive_words',
  'users', 'habits', 'anniversaries', 'point_records'
)
ORDER BY tablename, policyname;
