-- 问题反馈表
-- 在 Supabase SQL Editor 中执行此脚本

CREATE TABLE IF NOT EXISTS user_feedback (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'other' CHECK (category IN ('bug', 'feature', 'improvement', 'other')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'in_progress', 'resolved')),
  admin_reply TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_feedback_user_id ON user_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_user_feedback_status ON user_feedback(status);
CREATE INDEX IF NOT EXISTS idx_user_feedback_created_at ON user_feedback(created_at DESC);

-- RLS 策略
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- 用户只能查看自己的反馈
CREATE POLICY "Users can view own feedback"
  ON user_feedback FOR SELECT
  USING (auth.uid()::text = user_id);

-- 用户可以创建反馈
CREATE POLICY "Users can create feedback"
  ON user_feedback FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

-- 用户不能修改自己的反馈（只有管理员可以修改）
-- 管理员通过 service_role key 绕过 RLS

-- 禁止用户删除反馈
-- 管理员通过 service_role key 绕过 RLS

-- 注意：如果项目未使用 Supabase Auth（而是自定义 users 表），
-- 需要将上面的 auth.uid()::text 替换为适当的认证逻辑，
-- 或者直接禁用 RLS 并通过应用层控制权限：
-- ALTER TABLE user_feedback DISABLE ROW LEVEL SECURITY;
