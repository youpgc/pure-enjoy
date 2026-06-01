-- ============================================================
-- 最终修复 dict_types 和 dict_items 表结构
-- 适配已存在的表结构（code/name 列）
-- ============================================================

-- 1. 先删除之前错误插入的数据（如果有）
DELETE FROM dict_items WHERE type_id IN (SELECT id FROM dict_types WHERE code IS NULL);
DELETE FROM dict_types WHERE code IS NULL;

-- 2. 检查 dict_types 表的实际结构，添加缺失的列
DO $$
DECLARE
    col_exists BOOLEAN;
BEGIN
    -- 检查 type_code 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'type_code'
    ) INTO col_exists;
    
    -- 如果不存在 type_code 但存在 code，则添加 type_code 列
    IF NOT col_exists THEN
        ALTER TABLE dict_types ADD COLUMN type_code VARCHAR(50);
        -- 将 code 列的数据复制到 type_code
        UPDATE dict_types SET type_code = code WHERE type_code IS NULL;
    END IF;
    
    -- 检查 type_name 列是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'type_name'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        ALTER TABLE dict_types ADD COLUMN type_name VARCHAR(100);
        -- 将 name 列的数据复制到 type_name
        UPDATE dict_types SET type_name = name WHERE type_name IS NULL;
    END IF;
    
    -- 检查其他列
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'description') THEN
        ALTER TABLE dict_types ADD COLUMN description TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'sort_order') THEN
        ALTER TABLE dict_types ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'is_system') THEN
        ALTER TABLE dict_types ADD COLUMN is_system BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'is_active') THEN
        ALTER TABLE dict_types ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
END $$;

-- 3. 更新现有数据，填充 type_code 和 type_name
UPDATE dict_types SET 
    type_code = COALESCE(type_code, code),
    type_name = COALESCE(type_name, name),
    description = COALESCE(description, ''),
    sort_order = COALESCE(sort_order, 0),
    is_system = COALESCE(is_system, false),
    is_active = COALESCE(is_active, true)
WHERE type_code IS NULL OR type_name IS NULL;

-- 4. 检查 dict_items 表结构
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'type_id') THEN
        ALTER TABLE dict_items ADD COLUMN type_id UUID;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_code') THEN
        ALTER TABLE dict_items ADD COLUMN item_code VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_name') THEN
        ALTER TABLE dict_items ADD COLUMN item_name VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_value') THEN
        ALTER TABLE dict_items ADD COLUMN item_value TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'sort_order') THEN
        ALTER TABLE dict_items ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'is_default') THEN
        ALTER TABLE dict_items ADD COLUMN is_default BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'is_active') THEN
        ALTER TABLE dict_items ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'extra_data') THEN
        ALTER TABLE dict_items ADD COLUMN extra_data JSONB;
    END IF;
END $$;

-- 5. 如果 dict_items 表有旧的 code/name 列，复制数据
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'code') THEN
        UPDATE dict_items SET item_code = code WHERE item_code IS NULL AND code IS NOT NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'name') THEN
        UPDATE dict_items SET item_name = name WHERE item_name IS NULL AND name IS NOT NULL;
    END IF;
END $$;

-- 6. 插入缺失的字典类型（使用正确的列名）
INSERT INTO dict_types (code, name, type_code, type_name, description, sort_order, is_system, is_active) VALUES
('expense_category', '消费分类', 'expense_category', '消费分类', '记账消费分类', 0, true, true),
('mood_type', '心情类型', 'mood_type', '心情类型', '心情记录类型', 0, true, true),
('novel_category', '小说分类', 'novel_category', '小说分类', '小说分类', 0, true, true)
ON CONFLICT (code) DO UPDATE SET
    type_code = EXCLUDED.type_code,
    type_name = EXCLUDED.type_name,
    description = EXCLUDED.description,
    is_system = EXCLUDED.is_system;

-- 7. 插入字典项数据
-- 消费分类
INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'food', '餐饮', 'food', '餐饮', 'food', 1, true
FROM dict_types dt WHERE dt.code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'transport', '交通', 'transport', '交通', 'transport', 2, true
FROM dict_types dt WHERE dt.code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'shopping', '购物', 'shopping', '购物', 'shopping', 3, true
FROM dict_types dt WHERE dt.code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'entertainment', '娱乐', 'entertainment', '娱乐', 'entertainment', 4, true
FROM dict_types dt WHERE dt.code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'housing', '居住', 'housing', '居住', 'housing', 5, true
FROM dict_types dt WHERE dt.code = 'expense_category'
ON CONFLICT DO NOTHING;

-- 心情类型
INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'happy', '开心', 'happy', '开心', 'happy', 1, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'excited', '兴奋', 'excited', '兴奋', 'excited', 2, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'calm', '平静', 'calm', '平静', 'calm', 3, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'tired', '疲惫', 'tired', '疲惫', 'tired', 4, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'sad', '难过', 'sad', '难过', 'sad', 5, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'angry', '生气', 'angry', '生气', 'angry', 6, true
FROM dict_types dt WHERE dt.code = 'mood_type'
ON CONFLICT DO NOTHING;

-- 小说分类
INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'xianxia', '仙侠', 'xianxia', '仙侠', 'xianxia', 1, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'wuxia', '武侠', 'wuxia', '武侠', 'wuxia', 2, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'urban', '都市', 'urban', '都市', 'urban', 3, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'fantasy', '玄幻', 'fantasy', '玄幻', 'fantasy', 4, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'romance', '言情', 'romance', '言情', 'romance', 5, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'scifi', '科幻', 'scifi', '科幻', 'scifi', 6, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'history', '历史', 'history', '历史', 'history', 7, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, name, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'game', '游戏', 'game', '游戏', 'game', 8, true
FROM dict_types dt WHERE dt.code = 'novel_category'
ON CONFLICT DO NOTHING;

-- 修复完成
SELECT '字典表结构修复和数据插入完成' AS status;
