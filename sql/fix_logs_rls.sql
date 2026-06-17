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
-- 辅助：为指定表创建管理员 CRUD 策略
-- ============================================================

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOR table_name IN SELECT unnest(ARRAY[
    'error_logs',
    'operation_logs',
    'app_versions',
    'dict_types',
    'dict_items',
    'app_configs',
    'sensitive_word_logs',
    'files',
    'sensitive_words',
    'users',
    'habits',
    'anniversaries',
    'point_records'
  ]) LOOP
    -- 检查表是否存在
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = table_name AND table_schema = 'public') THEN
      -- 启用 RLS
      EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);

      -- 清除旧策略
      DECLARE r RECORD;
      FOR r IN SELECT policyname FROM pg_policies WHERE tablename = table_name LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, table_name);
      END LOOP;

      -- 管理员 SELECT
      EXECUTE format('CREATE POLICY %I_select_admin ON %I FOR SELECT USING (is_current_user_admin())',
        table_name || '_admin', table_name);

      -- 管理员 INSERT
      EXECUTE format('CREATE POLICY %I_insert_admin ON %I FOR INSERT WITH CHECK (is_current_user_admin())',
        table_name || '_admin_ins', table_name);

      -- 管理员 UPDATE
      EXECUTE format('CREATE POLICY %I_update_admin ON %I FOR UPDATE USING (is_current_user_admin())',
        table_name || '_admin_upd', table_name);

      -- 管理员 DELETE
      EXECUTE format('CREATE POLICY %I_delete_admin ON %I FOR DELETE USING (is_current_user_admin())',
        table_name || '_admin_del', table_name);

      -- 允许所有人 INSERT（用于错误日志上报等）
      IF table_name IN ('error_logs', 'operation_logs') THEN
        EXECUTE format('CREATE POLICY %I_insert_all ON %I FOR INSERT WITH CHECK (true)',
          table_name || '_all_ins', table_name);
      END IF;

      RAISE NOTICE '已为表 % 创建管理员 RLS 策略', table_name;
    ELSE
      RAISE NOTICE '表 % 不存在，跳过', table_name;
    END IF;
  END LOOP;
END $$;

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
