-- ============================================================
-- 修复习惯打卡相关表的 RLS 策略
-- 问题：系统使用自定义认证（非 Supabase Auth），auth.uid() 返回 null
-- 修复：改用 x-user-id header 进行用户身份识别
-- ============================================================

-- 辅助函数：获取当前请求的 x-user-id
CREATE OR REPLACE FUNCTION get_request_user_id()
RETURNS TEXT AS $$
BEGIN
  RETURN current_setting('request.headers', true)::json->>'x-user-id';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================
-- 1. reminder_schedules 表
-- ============================================================

-- 启用 RLS
ALTER TABLE reminder_schedules ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS reminder_schedules_select_user ON reminder_schedules;
DROP POLICY IF EXISTS reminder_schedules_insert_user ON reminder_schedules;
DROP POLICY IF EXISTS reminder_schedules_update_user ON reminder_schedules;
DROP POLICY IF EXISTS reminder_schedules_delete_user ON reminder_schedules;
DROP POLICY IF EXISTS reminder_schedules_select_admin ON reminder_schedules;
DROP POLICY IF EXISTS reminder_schedules_all_admin ON reminder_schedules;

-- 创建新策略（基于 x-user-id header）
CREATE POLICY reminder_schedules_select_user ON reminder_schedules
  FOR SELECT USING (user_id = get_request_user_id());

CREATE POLICY reminder_schedules_insert_user ON reminder_schedules
  FOR INSERT WITH CHECK (user_id = get_request_user_id());

CREATE POLICY reminder_schedules_update_user ON reminder_schedules
  FOR UPDATE USING (user_id = get_request_user_id());

CREATE POLICY reminder_schedules_delete_user ON reminder_schedules
  FOR DELETE USING (user_id = get_request_user_id());

-- ============================================================
-- 2. habits 表
-- ============================================================

-- 启用 RLS
ALTER TABLE habits ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'habits' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON habits', r.policyname);
  END LOOP;
END $$;

-- 创建新策略
CREATE POLICY habits_select_user ON habits
  FOR SELECT USING (user_id = get_request_user_id());

CREATE POLICY habits_insert_user ON habits
  FOR INSERT WITH CHECK (user_id = get_request_user_id());

CREATE POLICY habits_update_user ON habits
  FOR UPDATE USING (user_id = get_request_user_id());

CREATE POLICY habits_delete_user ON habits
  FOR DELETE USING (user_id = get_request_user_id());

-- ============================================================
-- 3. habit_checkins 表
-- ============================================================

-- 启用 RLS
ALTER TABLE habit_checkins ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'habit_checkins' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON habit_checkins', r.policyname);
  END LOOP;
END $$;

-- 创建新策略（通过 habit_id 关联 habits 表的 user_id）
CREATE POLICY habit_checkins_select_user ON habit_checkins
  FOR SELECT USING (
    habit_id IN (SELECT id FROM habits WHERE user_id = get_request_user_id())
  );

CREATE POLICY habit_checkins_insert_user ON habit_checkins
  FOR INSERT WITH CHECK (
    habit_id IN (SELECT id FROM habits WHERE user_id = get_request_user_id())
  );

CREATE POLICY habit_checkins_delete_user ON habit_checkins
  FOR DELETE USING (
    habit_id IN (SELECT id FROM habits WHERE user_id = get_request_user_id())
  );

-- ============================================================
-- 4. point_records 表
-- ============================================================

-- 启用 RLS
ALTER TABLE point_records ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'point_records' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON point_records', r.policyname);
  END LOOP;
END $$;

-- 创建新策略
CREATE POLICY point_records_select_user ON point_records
  FOR SELECT USING (user_id = get_request_user_id());

CREATE POLICY point_records_insert_user ON point_records
  FOR INSERT WITH CHECK (user_id = get_request_user_id());

CREATE POLICY point_records_update_user ON point_records
  FOR UPDATE USING (user_id = get_request_user_id());

CREATE POLICY point_records_delete_user ON point_records
  FOR DELETE USING (user_id = get_request_user_id());
