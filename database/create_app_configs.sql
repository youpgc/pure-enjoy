-- ============================================================
-- 迁移脚本：创建 app_configs 表
-- 描述：用于存储App端的富文本配置内容（关于、隐私政策、用户协议、帮助中心）
-- 日期：2026-05-28
-- 项目：纯享 (Pure Enjoy)
-- ============================================================

-- 1. 创建 app_configs 表
CREATE TABLE IF NOT EXISTS app_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key VARCHAR(100) NOT NULL UNIQUE,
  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  config_type VARCHAR(50) NOT NULL DEFAULT 'rich_text',
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. 添加索引
CREATE INDEX IF NOT EXISTS idx_app_configs_key ON app_configs(config_key);
CREATE INDEX IF NOT EXISTS idx_app_configs_active ON app_configs(is_active);

-- 3. 插入默认数据
INSERT INTO app_configs (config_key, title, content, config_type, sort_order) VALUES
('about', '关于纯享', '<h2>关于纯享</h2><p>纯享是一款专注于记录生活的应用，帮助您轻松管理日常记账、心情日记、体重记录等。</p><p>版本：1.6.0</p>', 'rich_text', 1),
('privacy_policy', '隐私政策', '<h2>隐私政策</h2><p>我们重视您的隐私保护。本隐私政策说明了我们如何收集、使用和保护您的个人信息。</p><h3>1. 信息收集</h3><p>我们仅收集为您提供服务所必需的信息。</p><h3>2. 信息使用</h3><p>您的信息仅用于提供和改善我们的服务。</p><h3>3. 信息保护</h3><p>我们采用行业标准的安全措施保护您的个人信息。</p>', 'rich_text', 2),
('user_agreement', '用户协议', '<h2>用户协议</h2><p>欢迎使用纯享！请仔细阅读以下条款。</p><h3>1. 服务说明</h3><p>纯享为用户提供生活记录和管理服务。</p><h3>2. 用户责任</h3><p>用户应合法使用本应用，不得利用本应用从事违法活动。</p><h3>3. 知识产权</h3><p>本应用的所有内容均受知识产权法保护。</p>', 'rich_text', 3),
('help_center', '帮助中心', '<h2>帮助中心</h2><h3>常见问题</h3><p><strong>Q: 如何添加记账记录？</strong></p><p>A: 进入"生活"页面，点击"记账"模块，即可添加新的消费记录。</p><p><strong>Q: 如何写心情日记？</strong></p><p>A: 进入"生活"页面，点击"心情日记"模块，选择当天心情并写下感受。</p><p><strong>Q: 数据会同步到云端吗？</strong></p><p>A: 是的，您的数据会自动同步到云端，换设备登录后即可恢复。</p><p><strong>Q: 如何联系客服？</strong></p><p>A: 您可以通过邮件 pureenjoy@example.com 联系我们。</p>', 'rich_text', 4)
ON CONFLICT (config_key) DO NOTHING;

-- 4. 启用RLS（Row Level Security）
ALTER TABLE app_configs ENABLE ROW LEVEL SECURITY;

-- 5. 创建RLS策略：允许所有人读取活跃配置
CREATE POLICY "Anyone can view active app configs" ON app_configs
  FOR SELECT USING (is_active = true);

-- 6. 创建RLS策略：允许管理员管理配置
CREATE POLICY "Admins can manage app configs" ON app_configs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role IN ('admin', 'super_admin')
    )
  );
