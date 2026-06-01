-- ============================================================
-- 纯享 App 数据库 Schema 完整文档
-- Supabase: mhdrbjpqmzswswoazwjg
-- 生成日期: 2026-05-29
-- 说明: 三端对齐（App端 Flutter + 管理端 React + Supabase）
-- ============================================================

-- ============================================================
-- 一、users 表 —— 用户表
-- App端字段: id, email, phone, nickname, avatar_url, username, bio, gender, birthday, location, occupation, company, website
-- 管理端字段: role, member_level, points, status, register_ip, last_login_ip, last_login_at, login_count
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(32) PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50),
    avatar_url TEXT,
    -- 扩展资料字段 (V1.9.2)
    username VARCHAR(50),
    bio TEXT,
    gender VARCHAR(10) DEFAULT '保密',
    birthday DATE,
    location VARCHAR(100),
    occupation VARCHAR(50),
    company VARCHAR(100),
    website VARCHAR(255),
    role VARCHAR(20) DEFAULT 'user',
    member_level VARCHAR(20) DEFAULT 'free',
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
-- 二、expenses 表 —— 消费记录
-- App端字段: id, user_id, amount, category, note, date, created_at
-- 管理端字段: id, user_id, amount, category, note, date, created_at, updated_at
-- 关键: 日期字段是 date，不是 expense_date；备注字段是 note，不是 description
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

-- ============================================================
-- 三、mood_diaries 表 —— 心情日记
-- App端字段: id, user_id, mood, mood_label, content, date, created_at
-- 管理端字段: id, user_id, mood, mood_label, content, date, created_at, updated_at
-- 关键: tags 字段已从 App 端移除（数据库中可能已存在但不使用）
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

-- ============================================================
-- 四、weight_records 表 —— 体重记录
-- App端字段: id, user_id, weight, bmi, body_fat, note, date, created_at
-- 管理端字段: id, user_id, weight, bmi, body_fat, note, date, created_at, updated_at
-- 关键: 日期字段是 date，不是 record_date
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

-- ============================================================
-- 五、notes 表 —— 笔记
-- App端字段: id, user_id, title, content, category, tags, is_pinned, created_at, updated_at
-- 管理端字段: id, user_id, title, content, category, tags, is_pinned, created_at, updated_at
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

-- ============================================================
-- 六、user_favorites 表 —— 收藏夹
-- App端字段: id, user_id, title, url, description, category, tags, is_pinned, created_at
-- 管理端字段: id, user_id, title, url, description, category, tags, is_pinned, created_at, updated_at
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

-- ============================================================
-- 七、user_reminders 表 —— 提醒事项
-- App端字段: id, user_id, title, description, remind_at, is_completed, priority, created_at
-- 管理端字段: id, user_id, title, description, remind_at, is_completed, priority, created_at, updated_at
-- 关键: 没有 repeat_type 字段（已从 App 端移除）
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

-- ============================================================
-- 八、user_habits 表 —— 习惯打卡
-- App端字段: id, user_id, name, description, frequency, target_days, current_streak, max_streak, total_checkins, color, is_active, created_at
-- 管理端字段: id, user_id, name, description, frequency, target_days, current_streak, max_streak, total_checkins, color, is_active, created_at, updated_at
-- 关键: 没有 start_date 字段（已从 App 端移除）
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

-- ============================================================
-- 九、habit_checkins 表 —— 打卡记录
-- App端字段: id, habit_id, checkin_at, created_at
-- 关键: 没有 user_id 字段（已从 App 端移除）；没有 note 字段（已从 App 端移除）
-- ============================================================
CREATE TABLE IF NOT EXISTS habit_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_id UUID NOT NULL,
    checkin_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 十、novels 表 —— 小说
-- App端: 只读，仅通过 user_id=is.null 过滤公共小说
-- 管理端: 完整 CRUD，包括 is_published 上架/下架
-- 关键: App 端不使用 is_published 字段（已从 App 端移除过滤条件）
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

-- ============================================================
-- 十一、novel_chapters 表 —— 小说章节
-- App端: 只读（按 chapter_num 排序获取章节列表和内容）
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
-- 十二、user_novels 表 —— 用户书架/阅读进度
-- App端: 完整 CRUD（添加到书架、更新阅读进度）
-- 管理端: 完整 CRUD（查看所有用户书架记录）
-- 关键: 没有 book_shelves 表（App 端已统一使用 user_novels）
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
-- 十三、app_versions 表 —— App 版本管理
-- App端查询: status=eq.released
-- 管理端: 完整 CRUD
-- 关键: is_force_update 字段不存在，使用 release_type == 'force' 判断
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
-- 十四、app_configs 表 —— App 配置
-- App端: 只读（按 config_key 查询配置内容）
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
-- 十五、admin_users 表 —— 管理员用户（与管理后台配套）
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

-- ============================================================
-- 十六、role_permissions 表 —— 角色权限
-- ============================================================
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id VARCHAR(20) NOT NULL,
    permission_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 十七、operation_logs 表 —— 操作日志
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
-- 十八、error_logs 表 —— 错误日志
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
-- RLS 行级安全策略
-- ============================================================

-- expenses: 用户只能操作自己的数据
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "expenses_owner" ON expenses FOR ALL USING (user_id = auth.uid());

-- mood_diaries: 用户只能操作自己的数据
ALTER TABLE mood_diaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "mood_diaries_owner" ON mood_diaries FOR ALL USING (user_id = auth.uid());

-- weight_records: 用户只能操作自己的数据
ALTER TABLE weight_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "weight_records_owner" ON weight_records FOR ALL USING (user_id = auth.uid());

-- notes: 用户只能操作自己的数据
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notes_owner" ON notes FOR ALL USING (user_id = auth.uid());

-- user_favorites: 用户只能操作自己的数据
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_favorites_owner" ON user_favorites FOR ALL USING (user_id = auth.uid());

-- user_reminders: 用户只能操作自己的数据
ALTER TABLE user_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_reminders_owner" ON user_reminders FOR ALL USING (user_id = auth.uid());

-- user_habits: 用户只能操作自己的数据
ALTER TABLE user_habits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_habits_owner" ON user_habits FOR ALL USING (user_id = auth.uid());

-- habit_checkins: 用户只能操作自己的数据
ALTER TABLE habit_checkins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "habit_checkins_owner" ON habit_checkins FOR ALL USING (habit_id IN (SELECT id FROM user_habits WHERE user_id = auth.uid()));

-- novels: 公开小说允许读取
ALTER TABLE novels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "novels_public_read" ON novels FOR SELECT USING (user_id IS NULL);
CREATE POLICY "novels_owner" ON novels FOR ALL USING (user_id = auth.uid());

-- novel_chapters: 公开小说章节允许读取
ALTER TABLE novel_chapters ENABLE ROW LEVEL SECURITY;
CREATE POLICY "novel_chapters_public_read" ON novel_chapters FOR SELECT USING (novel_id IN (SELECT id FROM novels WHERE user_id IS NULL));
CREATE POLICY "novel_chapters_owner" ON novel_chapters FOR ALL USING (novel_id IN (SELECT id FROM novels WHERE user_id = auth.uid()));

-- user_novels: 用户只能操作自己的书架
ALTER TABLE user_novels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_novels_owner" ON user_novels FOR ALL USING (user_id = auth.uid());

-- app_versions: 所有人可读取
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_versions_read_all" ON app_versions FOR SELECT USING (true);

-- app_configs: 所有人可读取
ALTER TABLE app_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_configs_read_all" ON app_configs FOR SELECT USING (true);

-- admin_users: 无 RLS（由管理后台直接操作）
-- operation_logs: 无 RLS
-- error_logs: 无 RLS
-- role_permissions: 无 RLS

-- ============================================================
-- 索引
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
