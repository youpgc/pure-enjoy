-- ============================================================
-- 修复敏感词表 RLS 策略 - 允许管理后台进行 CRUD 操作
-- 日期: 2026-06-02
-- 问题: 之前的策略只允许 SELECT，导致管理后台无法添加/修改/删除敏感词
-- ============================================================

-- ============================================================
-- 1. 修复 sensitive_words 表 RLS 策略
-- ============================================================

ALTER TABLE sensitive_words ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "sensitive_words_anon_select" ON sensitive_words;
DROP POLICY IF EXISTS "sensitive_words_allow_all" ON sensitive_words;

-- 创建新策略：允许所有操作（管理后台使用 service_role key）
-- 注意：生产环境应该使用更严格的策略
CREATE POLICY "sensitive_words_allow_all" ON sensitive_words
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 2. 修复 sensitive_word_configs 表 RLS 策略
-- ============================================================

ALTER TABLE sensitive_word_configs ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "sensitive_word_configs_anon_select" ON sensitive_word_configs;
DROP POLICY IF EXISTS "sensitive_word_configs_allow_all" ON sensitive_word_configs;

-- 创建新策略：允许所有操作
CREATE POLICY "sensitive_word_configs_allow_all" ON sensitive_word_configs
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 3. 修复 sensitive_word_logs 表 RLS 策略
-- ============================================================

ALTER TABLE sensitive_word_logs ENABLE ROW LEVEL SECURITY;

-- 删除旧策略（如果存在）
DROP POLICY IF EXISTS "sensitive_word_logs_anon_select" ON sensitive_word_logs;
DROP POLICY IF EXISTS "sensitive_word_logs_allow_all" ON sensitive_word_logs;

-- 创建新策略：允许所有操作
CREATE POLICY "sensitive_word_logs_allow_all" ON sensitive_word_logs
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 完成
-- ============================================================
