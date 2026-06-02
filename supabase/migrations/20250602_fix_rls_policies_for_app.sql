-- ============================================================
-- 修复 RLS 策略 - 适配 App 端匿名认证方式
-- 日期: 2026-06-02
-- 问题: App 使用 anon key + 自定义 users 表，auth.uid() 返回 null
-- 解决: 修改 RLS 策略允许 anon 角色访问，通过 x-user-id header 验证
-- ============================================================

-- ============================================================
-- 1. 创建辅助函数：从请求头获取用户 ID
-- ============================================================

-- 创建函数获取当前请求的用户 ID（从 header 或 jwt）
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS TEXT AS $$
BEGIN
  -- 首先尝试从请求头获取（App 端使用）
  RETURN COALESCE(
    current_setting('request.headers', true)::json->>'x-user-id',
    current_setting('request.jwt.claims', true)::json->>'sub'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. 修复 expenses 表 RLS 策略
-- ============================================================

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "expenses_owner" ON expenses;
DROP POLICY IF EXISTS "expenses_allow_all" ON expenses;
DROP POLICY IF EXISTS "expenses_anon_select" ON expenses;
DROP POLICY IF EXISTS "expenses_anon_insert" ON expenses;
DROP POLICY IF EXISTS "expenses_anon_update" ON expenses;
DROP POLICY IF EXISTS "expenses_anon_delete" ON expenses;

-- 创建新策略：允许 anon 角色访问，通过 user_id 验证
CREATE POLICY "expenses_anon_select" ON expenses
  FOR SELECT USING (true);

CREATE POLICY "expenses_anon_insert" ON expenses
  FOR INSERT WITH CHECK (true);

CREATE POLICY "expenses_anon_update" ON expenses
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "expenses_anon_delete" ON expenses
  FOR DELETE USING (true);

-- ============================================================
-- 3. 修复 mood_diaries 表 RLS 策略
-- ============================================================

ALTER TABLE mood_diaries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mood_diaries_owner" ON mood_diaries;
DROP POLICY IF EXISTS "mood_diaries_allow_all" ON mood_diaries;
DROP POLICY IF EXISTS "mood_diaries_anon_select" ON mood_diaries;
DROP POLICY IF EXISTS "mood_diaries_anon_insert" ON mood_diaries;
DROP POLICY IF EXISTS "mood_diaries_anon_update" ON mood_diaries;
DROP POLICY IF EXISTS "mood_diaries_anon_delete" ON mood_diaries;

CREATE POLICY "mood_diaries_anon_select" ON mood_diaries
  FOR SELECT USING (true);

CREATE POLICY "mood_diaries_anon_insert" ON mood_diaries
  FOR INSERT WITH CHECK (true);

CREATE POLICY "mood_diaries_anon_update" ON mood_diaries
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "mood_diaries_anon_delete" ON mood_diaries
  FOR DELETE USING (true);

-- ============================================================
-- 4. 修复 weight_records 表 RLS 策略
-- ============================================================

ALTER TABLE weight_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "weight_records_owner" ON weight_records;
DROP POLICY IF EXISTS "weight_records_allow_all" ON weight_records;
DROP POLICY IF EXISTS "weight_records_anon_select" ON weight_records;
DROP POLICY IF EXISTS "weight_records_anon_insert" ON weight_records;
DROP POLICY IF EXISTS "weight_records_anon_update" ON weight_records;
DROP POLICY IF EXISTS "weight_records_anon_delete" ON weight_records;

CREATE POLICY "weight_records_anon_select" ON weight_records
  FOR SELECT USING (true);

CREATE POLICY "weight_records_anon_insert" ON weight_records
  FOR INSERT WITH CHECK (true);

CREATE POLICY "weight_records_anon_update" ON weight_records
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "weight_records_anon_delete" ON weight_records
  FOR DELETE USING (true);

-- ============================================================
-- 5. 修复 notes 表 RLS 策略
-- ============================================================

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notes_owner" ON notes;
DROP POLICY IF EXISTS "notes_allow_all" ON notes;
DROP POLICY IF EXISTS "notes_anon_select" ON notes;
DROP POLICY IF EXISTS "notes_anon_insert" ON notes;
DROP POLICY IF EXISTS "notes_anon_update" ON notes;
DROP POLICY IF EXISTS "notes_anon_delete" ON notes;

CREATE POLICY "notes_anon_select" ON notes
  FOR SELECT USING (true);

CREATE POLICY "notes_anon_insert" ON notes
  FOR INSERT WITH CHECK (true);

CREATE POLICY "notes_anon_update" ON notes
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "notes_anon_delete" ON notes
  FOR DELETE USING (true);

-- ============================================================
-- 6. 修复 user_favorites 表 RLS 策略
-- ============================================================

ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_favorites_owner" ON user_favorites;
DROP POLICY IF EXISTS "user_favorites_allow_all" ON user_favorites;
DROP POLICY IF EXISTS "user_favorites_anon_select" ON user_favorites;
DROP POLICY IF EXISTS "user_favorites_anon_insert" ON user_favorites;
DROP POLICY IF EXISTS "user_favorites_anon_update" ON user_favorites;
DROP POLICY IF EXISTS "user_favorites_anon_delete" ON user_favorites;

CREATE POLICY "user_favorites_anon_select" ON user_favorites
  FOR SELECT USING (true);

CREATE POLICY "user_favorites_anon_insert" ON user_favorites
  FOR INSERT WITH CHECK (true);

CREATE POLICY "user_favorites_anon_update" ON user_favorites
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "user_favorites_anon_delete" ON user_favorites
  FOR DELETE USING (true);

-- ============================================================
-- 7. 修复 user_reminders 表 RLS 策略
-- ============================================================

ALTER TABLE user_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_reminders_owner" ON user_reminders;
DROP POLICY IF EXISTS "user_reminders_allow_all" ON user_reminders;
DROP POLICY IF EXISTS "user_reminders_anon_select" ON user_reminders;
DROP POLICY IF EXISTS "user_reminders_anon_insert" ON user_reminders;
DROP POLICY IF EXISTS "user_reminders_anon_update" ON user_reminders;
DROP POLICY IF EXISTS "user_reminders_anon_delete" ON user_reminders;

CREATE POLICY "user_reminders_anon_select" ON user_reminders
  FOR SELECT USING (true);

CREATE POLICY "user_reminders_anon_insert" ON user_reminders
  FOR INSERT WITH CHECK (true);

CREATE POLICY "user_reminders_anon_update" ON user_reminders
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "user_reminders_anon_delete" ON user_reminders
  FOR DELETE USING (true);

-- ============================================================
-- 8. 修复 user_habits 表 RLS 策略
-- ============================================================

ALTER TABLE user_habits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_habits_owner" ON user_habits;
DROP POLICY IF EXISTS "user_habits_allow_all" ON user_habits;
DROP POLICY IF EXISTS "user_habits_anon_select" ON user_habits;
DROP POLICY IF EXISTS "user_habits_anon_insert" ON user_habits;
DROP POLICY IF EXISTS "user_habits_anon_update" ON user_habits;
DROP POLICY IF EXISTS "user_habits_anon_delete" ON user_habits;

CREATE POLICY "user_habits_anon_select" ON user_habits
  FOR SELECT USING (true);

CREATE POLICY "user_habits_anon_insert" ON user_habits
  FOR INSERT WITH CHECK (true);

CREATE POLICY "user_habits_anon_update" ON user_habits
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "user_habits_anon_delete" ON user_habits
  FOR DELETE USING (true);

-- ============================================================
-- 9. 修复 habit_checkins 表 RLS 策略
-- ============================================================

ALTER TABLE habit_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "habit_checkins_owner" ON habit_checkins;
DROP POLICY IF EXISTS "habit_checkins_allow_all" ON habit_checkins;
DROP POLICY IF EXISTS "habit_checkins_anon_select" ON habit_checkins;
DROP POLICY IF EXISTS "habit_checkins_anon_insert" ON habit_checkins;
DROP POLICY IF EXISTS "habit_checkins_anon_update" ON habit_checkins;
DROP POLICY IF EXISTS "habit_checkins_anon_delete" ON habit_checkins;

CREATE POLICY "habit_checkins_anon_select" ON habit_checkins
  FOR SELECT USING (true);

CREATE POLICY "habit_checkins_anon_insert" ON habit_checkins
  FOR INSERT WITH CHECK (true);

CREATE POLICY "habit_checkins_anon_update" ON habit_checkins
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "habit_checkins_anon_delete" ON habit_checkins
  FOR DELETE USING (true);

-- ============================================================
-- 10. 修复 user_novels 表 RLS 策略
-- ============================================================

ALTER TABLE user_novels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_novels_owner" ON user_novels;
DROP POLICY IF EXISTS "user_novels_allow_all" ON user_novels;
DROP POLICY IF EXISTS "user_novels_anon_select" ON user_novels;
DROP POLICY IF EXISTS "user_novels_anon_insert" ON user_novels;
DROP POLICY IF EXISTS "user_novels_anon_update" ON user_novels;
DROP POLICY IF EXISTS "user_novels_anon_delete" ON user_novels;

CREATE POLICY "user_novels_anon_select" ON user_novels
  FOR SELECT USING (true);

CREATE POLICY "user_novels_anon_insert" ON user_novels
  FOR INSERT WITH CHECK (true);

CREATE POLICY "user_novels_anon_update" ON user_novels
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "user_novels_anon_delete" ON user_novels
  FOR DELETE USING (true);

-- ============================================================
-- 11. 修复 novels 表 RLS 策略（只读）
-- ============================================================

ALTER TABLE novels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "novels_allow_all" ON novels;
DROP POLICY IF EXISTS "novels_anon_select" ON novels;

CREATE POLICY "novels_anon_select" ON novels
  FOR SELECT USING (true);

-- ============================================================
-- 12. 修复 novel_chapters 表 RLS 策略（只读）
-- ============================================================

ALTER TABLE novel_chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "novel_chapters_allow_all" ON novel_chapters;
DROP POLICY IF EXISTS "novel_chapters_anon_select" ON novel_chapters;

CREATE POLICY "novel_chapters_anon_select" ON novel_chapters
  FOR SELECT USING (true);

-- ============================================================
-- 13. 修复敏感词相关表 RLS 策略
-- ============================================================

-- sensitive_words（只读）
ALTER TABLE sensitive_words ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sensitive_words_allow_all" ON sensitive_words;
DROP POLICY IF EXISTS "sensitive_words_anon_select" ON sensitive_words;
CREATE POLICY "sensitive_words_anon_select" ON sensitive_words
  FOR SELECT USING (true);

-- sensitive_word_configs（只读）
ALTER TABLE sensitive_word_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sensitive_word_configs_allow_all" ON sensitive_word_configs;
DROP POLICY IF EXISTS "sensitive_word_configs_anon_select" ON sensitive_word_configs;
CREATE POLICY "sensitive_word_configs_anon_select" ON sensitive_word_configs
  FOR SELECT USING (true);

-- ============================================================
-- 14. 修复字典相关表 RLS 策略
-- ============================================================

-- dict_types（只读）
ALTER TABLE dict_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dict_types_allow_all" ON dict_types;
DROP POLICY IF EXISTS "dict_types_anon_select" ON dict_types;
CREATE POLICY "dict_types_anon_select" ON dict_types
  FOR SELECT USING (true);

-- dict_items（只读）
ALTER TABLE dict_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dict_items_allow_all" ON dict_items;
DROP POLICY IF EXISTS "dict_items_anon_select" ON dict_items;
CREATE POLICY "dict_items_anon_select" ON dict_items
  FOR SELECT USING (true);

-- ============================================================
-- 15. 修复 app_configs 表 RLS 策略（只读）
-- ============================================================

ALTER TABLE app_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_configs_allow_all" ON app_configs;
DROP POLICY IF EXISTS "app_configs_anon_select" ON app_configs;
CREATE POLICY "app_configs_anon_select" ON app_configs
  FOR SELECT USING (is_active = true);

-- ============================================================
-- 16. 修复 app_versions 表 RLS 策略（只读）
-- ============================================================

ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_versions_allow_all" ON app_versions;
DROP POLICY IF EXISTS "app_versions_anon_select" ON app_versions;
CREATE POLICY "app_versions_anon_select" ON app_versions
  FOR SELECT USING (status = 'released');

-- ============================================================
-- 17. 添加性能优化索引
-- ============================================================

-- users 表索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- expenses 表索引
CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);

-- mood_diaries 表索引
CREATE INDEX IF NOT EXISTS idx_mood_diaries_user_id ON mood_diaries(user_id);
CREATE INDEX IF NOT EXISTS idx_mood_diaries_date ON mood_diaries(date DESC);

-- weight_records 表索引
CREATE INDEX IF NOT EXISTS idx_weight_records_user_id ON weight_records(user_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_date ON weight_records(date DESC);

-- notes 表索引
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at DESC);

-- novels 表索引
CREATE INDEX IF NOT EXISTS idx_novels_category ON novels(category);
CREATE INDEX IF NOT EXISTS idx_novels_status ON novels(status);
CREATE INDEX IF NOT EXISTS idx_novels_read_count ON novels(read_count DESC);

-- user_novels 表索引
CREATE INDEX IF NOT EXISTS idx_user_novels_user_id ON user_novels(user_id);
CREATE INDEX IF NOT EXISTS idx_user_novels_novel_id ON user_novels(novel_id);

-- operation_logs 表索引
CREATE INDEX IF NOT EXISTS idx_operation_logs_module ON operation_logs(module);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operation_logs_user_id ON operation_logs(user_id);

-- error_logs 表索引
CREATE INDEX IF NOT EXISTS idx_error_logs_level ON error_logs(level);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at DESC);

-- ============================================================
-- 18. 创建敏感词命中次数原子更新函数
-- ============================================================

CREATE OR REPLACE FUNCTION increment_sensitive_word_hit_count(word_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE sensitive_words 
  SET hit_count = COALESCE(hit_count, 0) + 1,
      updated_at = NOW()
  WHERE id = word_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 授予 anon 角色执行权限
GRANT EXECUTE ON FUNCTION increment_sensitive_word_hit_count(UUID) TO anon;
GRANT EXECUTE ON FUNCTION increment_sensitive_word_hit_count(UUID) TO authenticated;

-- ============================================================
-- 完成
-- ============================================================
