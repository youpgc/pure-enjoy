-- ============================================================
-- 纯享 App - Supabase 数据库建表脚本
-- ============================================================
-- 使用方法：在 Supabase 控制台 → SQL Editor 中粘贴执行
-- ============================================================

-- 1. 消费记录表
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  category TEXT NOT NULL,
  note TEXT,
  date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced BOOLEAN NOT NULL DEFAULT TRUE
);

-- 2. 心情日记表
CREATE TABLE IF NOT EXISTS mood_diaries (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mood TEXT NOT NULL,
  mood_label TEXT,
  content TEXT,
  date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. 体重记录表
CREATE TABLE IF NOT EXISTS weight_records (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  weight DOUBLE PRECISION NOT NULL,
  note TEXT,
  date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced BOOLEAN NOT NULL DEFAULT TRUE
);

-- 4. 笔记表
CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT,
  category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pinned BOOLEAN NOT NULL DEFAULT FALSE,
  synced BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. 小说书架表
CREATE TABLE IF NOT EXISTS novels (
  id TEXT PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  author TEXT NOT NULL,
  cover_url TEXT,
  description TEXT,
  source TEXT NOT NULL,
  source_id TEXT NOT NULL,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ,
  last_chapter_index INTEGER NOT NULL DEFAULT 0,
  progress DOUBLE PRECISION NOT NULL DEFAULT 0,
  synced BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- RLS (Row Level Security) 策略
-- 用户只能访问自己的数据
-- ============================================================

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_diaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE novels ENABLE ROW LEVEL SECURITY;

-- 消费记录策略
CREATE POLICY "Users can view own expenses" ON expenses
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own expenses" ON expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own expenses" ON expenses
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own expenses" ON expenses
  FOR DELETE USING (auth.uid() = user_id);

-- 心情日记策略
CREATE POLICY "Users can view own mood_diaries" ON mood_diaries
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own mood_diaries" ON mood_diaries
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own mood_diaries" ON mood_diaries
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own mood_diaries" ON mood_diaries
  FOR DELETE USING (auth.uid() = user_id);

-- 体重记录策略
CREATE POLICY "Users can view own weight_records" ON weight_records
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own weight_records" ON weight_records
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own weight_records" ON weight_records
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own weight_records" ON weight_records
  FOR DELETE USING (auth.uid() = user_id);

-- 笔记策略
CREATE POLICY "Users can view own notes" ON notes
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own notes" ON notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own notes" ON notes
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own notes" ON notes
  FOR DELETE USING (auth.uid() = user_id);

-- 小说策略
CREATE POLICY "Users can view own novels" ON novels
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own novels" ON novels
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own novels" ON novels
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own novels" ON novels
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- 索引优化
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_expenses_user ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_mood_diaries_user ON mood_diaries(user_id);
CREATE INDEX IF NOT EXISTS idx_weight_records_user ON weight_records(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_user ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_novels_user ON novels(user_id);
