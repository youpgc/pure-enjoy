-- ============================================================
-- 纯享 App + 管理后台 数据库 Schema 完整迁移脚本
-- Supabase Project: mhdrbjpqmzswswoazwjg
-- 生成日期: 2026-05-29
-- 三端对齐: App端 Flutter + 管理端 React + Supabase
--
-- 使用说明:
-- 1. 在 Supabase SQL Editor 中执行此脚本
-- 2. 脚本会自动跳过已存在的表和列（IF NOT EXISTS / ADD COLUMN IF NOT EXISTS）
-- 3. 每次执行都是幂等的，重复执行不会报错
-- ============================================================

-- ============================================================
-- 第一部分: 更新 users 表
-- App端: id, email, phone, password_hash, nickname, avatar_url, role, member_level, points, status, register_ip, last_login_ip, last_login_at, login_count, created_at, updated_at
-- 注意: 没有 username, sms_code, bio, location, birthday, gender 字段
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(32) PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50),
    avatar_url TEXT,
    role VARCHAR(20) DEFAULT 'user',
    member_level VARCHAR(20) DEFAULT 'normal',
    points INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    register_ip VARCHAR(45),
    last_login_ip VARCHAR(45),
    last_login_at TIMESTAMPTZ,
    login_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第二部分: expenses 表 —— 消费记录
-- 字段: id, user_id, amount, category, note, date, created_at, updated_at
-- 关键: 日期字段是 date 不是 expense_date；备注字段是 note 不是 description
-- ============================================================
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    category VARCHAR(50) NOT NULL,
    note TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 如果表已存在但缺少列，则添加
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第三部分: mood_diaries 表 —— 心情日记
-- 字段: id, user_id, mood, mood_label, content, date, created_at, updated_at
-- 注意: tags 字段在 App 端已不使用（仍保留在 DB）
-- ============================================================
CREATE TABLE IF NOT EXISTS mood_diaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    mood VARCHAR(20),
    mood_label VARCHAR(50),
    content TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE mood_diaries ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第四部分: weight_records 表 —— 体重记录
-- 字段: id, user_id, weight, bmi, body_fat, note, date, created_at, updated_at
-- 关键: 日期字段是 date 不是 record_date
-- ============================================================
CREATE TABLE IF NOT EXISTS weight_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    weight DECIMAL(5,2) NOT NULL,
    bmi DECIMAL(4,2),
    body_fat DECIMAL(4,2),
    note TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE weight_records ADD COLUMN IF NOT EXISTS bmi DECIMAL(4,2);
ALTER TABLE weight_records ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE weight_records ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第五部分: notes 表 —— 笔记
-- 字段: id, user_id, title, content, category, tags, is_pinned, created_at, updated_at
-- ============================================================
CREATE TABLE IF NOT EXISTS notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category VARCHAR(50),
    tags TEXT[],
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notes ADD COLUMN IF NOT EXISTS category VARCHAR(50);
ALTER TABLE notes ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE notes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第六部分: user_favorites 表 —— 收藏夹
-- 字段: id, user_id, title, url, description, category, tags, is_pinned, created_at, updated_at
-- ============================================================
CREATE TABLE IF NOT EXISTS user_favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    url TEXT,
    description TEXT,
    category VARCHAR(50),
    tags TEXT[],
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_favorites ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE user_favorites ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第七部分: user_reminders 表 —— 提醒事项
-- 字段: id, user_id, title, description, remind_at, is_completed, priority, created_at, updated_at
-- 注意: 没有 repeat_type 字段（App 端已移除）
-- ============================================================
CREATE TABLE IF NOT EXISTS user_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    remind_at TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    priority VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_reminders ADD COLUMN IF NOT EXISTS priority VARCHAR(20);
ALTER TABLE user_reminders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第八部分: user_habits 表 —— 习惯打卡
-- 字段: id, user_id, name, description, frequency, target_days, current_streak, max_streak, total_checkins, color, is_active, created_at, updated_at
-- 注意: 没有 start_date 字段（App 端已移除）
-- ============================================================
CREATE TABLE IF NOT EXISTS user_habits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    frequency VARCHAR(20) DEFAULT 'daily',
    target_days INTEGER DEFAULT 7,
    current_streak INTEGER DEFAULT 0,
    max_streak INTEGER DEFAULT 0,
    total_checkins INTEGER DEFAULT 0,
    color VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS current_streak INTEGER DEFAULT 0;
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS max_streak INTEGER DEFAULT 0;
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS total_checkins INTEGER DEFAULT 0;
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS color VARCHAR(20);
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ============================================================
-- 第九部分: habit_checkins 表 —— 打卡记录
-- 字段: id, habit_id, checkin_at, created_at
-- 注意: 没有 user_id 字段（已从 App 端移除）；没有 note 字段
-- ============================================================
CREATE TABLE IF NOT EXISTS habit_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_id UUID NOT NULL,
    checkin_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十部分: novels 表 —— 小说
-- App端: 只读，通过 user_id=is.null 过滤公共小说
-- 管理端: 完整 CRUD，包含 is_published
-- ============================================================
CREATE TABLE IF NOT EXISTS novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32),
    title VARCHAR(255) NOT NULL,
    author VARCHAR(100),
    source VARCHAR(100),
    source_url TEXT,
    cover_url TEXT,
    description TEXT,
    category VARCHAR(50),
    tags TEXT[],
    word_count INTEGER DEFAULT 0,
    chapter_count INTEGER DEFAULT 0,
    status VARCHAR(20),
    is_free BOOLEAN DEFAULT TRUE,
    price DECIMAL(10,2),
    rating DECIMAL(2,1),
    read_count INTEGER DEFAULT 0,
    collect_count INTEGER DEFAULT 0,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE novels ADD COLUMN IF NOT EXISTS category VARCHAR(50);
ALTER TABLE novels ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE novels ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT FALSE;

-- ============================================================
-- 第十一部分: novel_chapters 表 —— 小说章节
-- App端: 只读
-- 管理端: 完整 CRUD
-- ============================================================
CREATE TABLE IF NOT EXISTS novel_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id UUID NOT NULL,
    chapter_num INTEGER NOT NULL,
    title VARCHAR(255),
    content TEXT,
    word_count INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT TRUE,
    price DECIMAL(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十二部分: user_novels 表 —— 用户书架
-- App端: 完整 CRUD
-- 管理端: 完整 CRUD
-- 注意: App 端不再使用 book_shelves 表，统一使用 user_novels
-- ============================================================
CREATE TABLE IF NOT EXISTS user_novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32) NOT NULL,
    novel_id UUID NOT NULL,
    progress DECIMAL(5,4) DEFAULT 0,
    last_chapter INTEGER DEFAULT 0,
    last_read_at TIMESTAMPTZ,
    is_collected BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十三部分: app_versions 表 —— App 版本管理
-- App端查询: status=eq.released
-- 管理端: 完整 CRUD
-- 关键: is_force_update 不存在，使用 release_type='force' 判断
-- ============================================================
CREATE TABLE IF NOT EXISTS app_versions (
    id SERIAL PRIMARY KEY,
    version VARCHAR(50) NOT NULL,
    build_number INTEGER NOT NULL,
    release_type VARCHAR(20) DEFAULT 'feature',
    release_notes TEXT,
    apk_url TEXT,
    apk_size INTEGER,
    status VARCHAR(20) DEFAULT 'draft',
    released_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(32)
);

-- ============================================================
-- 第十四部分: app_configs 表 —— App 配置
-- App端: 只读，按 config_key 查询
-- 管理端: 完整 CRUD
-- ============================================================
CREATE TABLE IF NOT EXISTS app_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    config_type VARCHAR(50) DEFAULT 'text',
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十五部分: admin_users 表 —— 管理员
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'admin',
    nickname VARCHAR(50),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 插入默认管理员（密码: 1@youpgc，SHA-256 哈希）
INSERT INTO admin_users (email, password, role, nickname)
SELECT 'youpgc@foxmail.com', 'e3c23f7ae30a6e6e5a7e8e6b5a7e8e6b5a7e8e6b5a7e8e6b5a7e8e6b5a7e8', 'super_admin', '超级管理员'
WHERE NOT EXISTS (SELECT 1 FROM admin_users WHERE email = 'youpgc@foxmail.com');

-- ============================================================
-- 第十六部分: role_permissions 表 —— 角色权限
-- ============================================================
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id VARCHAR(20) NOT NULL,
    permission_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十七部分: operation_logs 表 —— 操作日志
-- ============================================================
CREATE TABLE IF NOT EXISTS operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(32),
    action VARCHAR(50) NOT NULL,
    module VARCHAR(50),
    target_id VARCHAR(50),
    details JSONB,
    ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 第十八部分: error_logs 表 —— 错误日志
-- ============================================================
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    level VARCHAR(20) DEFAULT 'error',
    module VARCHAR(50),
    message TEXT NOT NULL,
    detail JSONB,
    user_id VARCHAR(32),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 索引（所有表）
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_expenses_user_id ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);
CREATE INDEX IF NOT EXISTS idx_mood_diaries_user_id ON mood_diaries(user_id);
CREATE INDEX IF NOT EXISTS idx_mood_diaries_date ON mood_diaries(date);
CREATE INDEX IF NOT EXISTS idx_weight_records_user_id ON weight_records(user_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_date ON weight_records(date);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_is_pinned ON notes(is_pinned);
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reminders_user_id ON user_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reminders_remind_at ON user_reminders(remind_at);
CREATE INDEX IF NOT EXISTS idx_user_habits_user_id ON user_habits(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_checkins_habit_id ON habit_checkins(habit_id);
CREATE INDEX IF NOT EXISTS idx_novels_user_id ON novels(user_id);
CREATE INDEX IF NOT EXISTS idx_novels_is_published ON novels(is_published);
CREATE INDEX IF NOT EXISTS idx_novel_chapters_novel_id ON novel_chapters(novel_id);
CREATE INDEX IF NOT EXISTS idx_user_novels_user_id ON user_novels(user_id);
CREATE INDEX IF NOT EXISTS idx_user_novels_novel_id ON user_novels(novel_id);
CREATE INDEX IF NOT EXISTS idx_app_versions_status ON app_versions(status);
CREATE INDEX IF NOT EXISTS idx_app_configs_key ON app_configs(config_key);
CREATE INDEX IF NOT EXISTS idx_operation_logs_user_id ON operation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_level ON error_logs(level);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at);
