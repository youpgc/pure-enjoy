-- ============================================================
-- 用户表扩展字段迁移
-- 版本: V1.9.2
-- 日期: 2025-06-01
-- 说明: 添加用户个人资料扩展字段，支持 App 端编辑个人资料功能
-- ============================================================

-- 添加用户个人资料扩展字段
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(10) DEFAULT '保密';
ALTER TABLE users ADD COLUMN IF NOT EXISTS birthday DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS occupation VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS company VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS website VARCHAR(255);

-- 添加注释
COMMENT ON COLUMN users.username IS '用户名（唯一标识名）';
COMMENT ON COLUMN users.bio IS '个人简介';
COMMENT ON COLUMN users.gender IS '性别（男/女/保密）';
COMMENT ON COLUMN users.birthday IS '生日日期';
COMMENT ON COLUMN users.location IS '所在地';
COMMENT ON COLUMN users.occupation IS '职业';
COMMENT ON COLUMN users.company IS '公司';
COMMENT ON COLUMN users.website IS '个人网站';

-- 创建唯一索引（username 可选唯一）
-- 注意: username 允许为空，非空值需要唯一
CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx ON users (username) WHERE username IS NOT NULL;

-- 更新 updated_at 触发器（如果存在）
-- 确保 updated_at 字段在更新时自动更新