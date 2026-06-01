-- ============================================================
-- 敏感词管理模块 - 数据库迁移
-- 包含: sensitive_words 表 + sensitive_word_logs 表
-- ============================================================

-- 1. 敏感词表
CREATE TABLE IF NOT EXISTS sensitive_words (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word VARCHAR(500) NOT NULL,                -- 敏感词/词组
  category VARCHAR(50) NOT NULL DEFAULT 'novel',  -- 分类: novel(小说), system(系统)
  level VARCHAR(20) NOT NULL DEFAULT 'block',    -- 级别: block(屏蔽), replace(替换), warn(警告)
  replace_word VARCHAR(500),               -- 替换词（level=replace 时生效）
  description TEXT,                        -- 备注说明
  match_mode VARCHAR(20) NOT NULL DEFAULT 'exact',  -- 匹配模式: exact(精确), contains(包含), regex(正则)
  is_active BOOLEAN NOT NULL DEFAULT TRUE,  -- 是否启用
  hit_count INTEGER NOT NULL DEFAULT 0,     -- 命中次数
  created_by VARCHAR(100),                  -- 创建人
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 分类索引
CREATE INDEX IF NOT EXISTS idx_sensitive_words_category ON sensitive_words(category);
-- 词索引（支持快速查找）
CREATE INDEX IF NOT EXISTS idx_sensitive_words_word ON sensitive_words(word);
-- 状态索引
CREATE INDEX IF NOT EXISTS idx_sensitive_words_active ON sensitive_words(is_active);

-- 添加注释
COMMENT ON TABLE sensitive_words IS '敏感词管理表';
COMMENT ON COLUMN sensitive_words.category IS '分类: novel-小说敏感词, system-系统敏感词';
COMMENT ON COLUMN sensitive_words.level IS '处理级别: block-直接屏蔽, replace-替换为指定词, warn-仅警告';
COMMENT ON COLUMN sensitive_words.match_mode IS '匹配模式: exact-精确匹配, contains-包含匹配, regex-正则匹配';

-- 2. 敏感词命中日志表
CREATE TABLE IF NOT EXISTS sensitive_word_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_id UUID NOT NULL REFERENCES sensitive_words(id) ON DELETE CASCADE,
  word VARCHAR(500) NOT NULL,                -- 命中的敏感词（冗余，防止词被删后日志丢失）
  category VARCHAR(50) NOT NULL,            -- 分类
  source VARCHAR(50) NOT NULL,              -- 来源: novel_content(小说内容), user_comment(用户评论), user_nickname(用户昵称) 等
  source_id VARCHAR(100),                   -- 来源记录ID
  user_id VARCHAR(100),                     -- 触发用户ID
  content_snippet TEXT,                     -- 命中内容片段（截取前后各50字符）
  action_taken VARCHAR(20) NOT NULL,        -- 处理动作: blocked(已屏蔽), replaced(已替换), warned(已警告)
  ip_address VARCHAR(50),                   -- 触发IP
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 日志索引
CREATE INDEX IF NOT EXISTS idx_swl_word_id ON sensitive_word_logs(word_id);
CREATE INDEX IF NOT EXISTS idx_swl_category ON sensitive_word_logs(category);
CREATE INDEX IF NOT EXISTS idx_swl_source ON sensitive_word_logs(source);
CREATE INDEX IF NOT EXISTS idx_swl_created_at ON sensitive_word_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_swl_user_id ON sensitive_word_logs(user_id);

COMMENT ON TABLE sensitive_word_logs IS '敏感词命中日志表';
COMMENT ON COLUMN sensitive_word_logs.source IS '来源类型: novel_content-小说内容, user_comment-用户评论, user_nickname-用户昵称, user_bio-用户简介';

-- 3. 敏感词分类开关配置（使用 app_configs 表）
-- 插入默认开关配置
INSERT INTO app_configs (key, value, description, created_at, updated_at)
VALUES
  ('sensitive_word_novel_enabled', 'false', '小说敏感词拦截开关', NOW(), NOW()),
  ('sensitive_word_system_enabled', 'false', '系统敏感词拦截开关', NOW(), NOW())
ON CONFLICT (key) DO NOTHING;

-- 4. 插入示例敏感词（可选，便于测试）
INSERT INTO sensitive_words (word, category, level, replace_word, description, match_mode, is_active, created_by) VALUES
  ('测试敏感词1', 'novel', 'replace', '***', '示例小说敏感词', 'exact', true, 'system'),
  ('测试敏感词2', 'system', 'block', NULL, '示例系统敏感词', 'contains', true, 'system')
ON CONFLICT DO NOTHING;
