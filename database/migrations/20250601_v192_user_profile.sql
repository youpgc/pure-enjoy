-- ============================================================
-- V1.9.2 个人资料扩展 - 数据库迁移
-- 执行日期: 2026-06-01
-- 内容: users 表新增个人资料扩展字段
-- ============================================================

-- 添加 users 表扩展字段
DO $$
BEGIN
    -- 用户名
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'username') THEN
        ALTER TABLE users ADD COLUMN username VARCHAR(100);
    END IF;

    -- 个性签名/简介
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'bio') THEN
        ALTER TABLE users ADD COLUMN bio TEXT;
    END IF;

    -- 性别
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gender') THEN
        ALTER TABLE users ADD COLUMN gender VARCHAR(10) DEFAULT '保密';
    END IF;

    -- 生日
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'birthday') THEN
        ALTER TABLE users ADD COLUMN birthday DATE;
    END IF;

    -- 所在地
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'location') THEN
        ALTER TABLE users ADD COLUMN location VARCHAR(100);
    END IF;

    -- 职业
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'occupation') THEN
        ALTER TABLE users ADD COLUMN occupation VARCHAR(100);
    END IF;

    -- 公司/组织
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'company') THEN
        ALTER TABLE users ADD COLUMN company VARCHAR(100);
    END IF;

    -- 个人网站
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'website') THEN
        ALTER TABLE users ADD COLUMN website VARCHAR(255);
    END IF;
END $$;

-- 迁移完成
SELECT 'V1.9.2 个人资料扩展字段添加完成' AS status;
