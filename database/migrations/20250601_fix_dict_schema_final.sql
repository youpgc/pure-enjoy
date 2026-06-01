-- ============================================================
-- 最终修复 dict_types 和 dict_items 表结构（v3）
-- 基于实际表结构分析，一次性修复所有问题
-- ============================================================
--
-- dict_types 实际 NOT NULL 列: id, code, name, status, created_at, updated_at
-- dict_items 实际 NOT NULL 列: id, type_id, code, label, status, created_at, updated_at
-- ============================================================

-- 1. 清理之前错误插入的空数据
DELETE FROM dict_items WHERE label IS NULL;
DELETE FROM dict_types WHERE name IS NULL;

-- 2. dict_types: 添加缺失的新列
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'type_code') THEN
        ALTER TABLE dict_types ADD COLUMN type_code VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'type_name') THEN
        ALTER TABLE dict_types ADD COLUMN type_name VARCHAR(100);
    END IF;
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

-- 3. dict_items: 添加缺失的新列
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_code') THEN
        ALTER TABLE dict_items ADD COLUMN item_code VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_name') THEN
        ALTER TABLE dict_items ADD COLUMN item_name VARCHAR(100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'item_value') THEN
        ALTER TABLE dict_items ADD COLUMN item_value TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'is_active') THEN
        ALTER TABLE dict_items ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'extra_data') THEN
        ALTER TABLE dict_items ADD COLUMN extra_data JSONB;
    END IF;
END $$;

-- 4. 回填新列数据
UPDATE dict_types SET type_code = code, type_name = name WHERE type_code IS NULL;
UPDATE dict_items SET item_code = code, item_name = label WHERE item_code IS NULL;

-- 5. 插入字典类型（填充所有 NOT NULL 列: code, name, status）
INSERT INTO dict_types (code, name, status, type_code, type_name, description, sort_order, is_system, is_active) VALUES
('expense_category', '消费分类', 'active', 'expense_category', '消费分类', '记账消费分类', 0, true, true),
('mood_type', '心情类型', 'active', 'mood_type', '心情类型', '心情记录类型', 0, true, true),
('novel_category', '小说分类', 'active', 'novel_category', '小说分类', '小说分类', 0, true, true)
ON CONFLICT (code) DO UPDATE SET
    type_code = EXCLUDED.type_code,
    type_name = EXCLUDED.type_name,
    description = EXCLUDED.description,
    is_system = EXCLUDED.is_system;

-- 6. 插入字典项（填充所有 NOT NULL 列: type_id, code, label, status）
-- 消费分类
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'food', '餐饮', 'active', 'food', '餐饮', 'food', 1, true FROM dict_types dt WHERE dt.code = 'expense_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'transport', '交通', 'active', 'transport', '交通', 'transport', 2, true FROM dict_types dt WHERE dt.code = 'expense_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'shopping', '购物', 'active', 'shopping', '购物', 'shopping', 3, true FROM dict_types dt WHERE dt.code = 'expense_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'entertainment', '娱乐', 'active', 'entertainment', '娱乐', 'entertainment', 4, true FROM dict_types dt WHERE dt.code = 'expense_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'housing', '居住', 'active', 'housing', '居住', 'housing', 5, true FROM dict_types dt WHERE dt.code = 'expense_category' ON CONFLICT DO NOTHING;

-- 心情类型
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'happy', '开心', 'active', 'happy', '开心', 'happy', 1, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'excited', '兴奋', 'active', 'excited', '兴奋', 'excited', 2, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'calm', '平静', 'active', 'calm', '平静', 'calm', 3, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'tired', '疲惫', 'active', 'tired', '疲惫', 'tired', 4, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'sad', '难过', 'active', 'sad', '难过', 'sad', 5, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'angry', '生气', 'active', 'angry', '生气', 'angry', 6, true FROM dict_types dt WHERE dt.code = 'mood_type' ON CONFLICT DO NOTHING;

-- 小说分类
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'xianxia', '仙侠', 'active', 'xianxia', '仙侠', 'xianxia', 1, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'wuxia', '武侠', 'active', 'wuxia', '武侠', 'wuxia', 2, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'urban', '都市', 'active', 'urban', '都市', 'urban', 3, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'fantasy', '玄幻', 'active', 'fantasy', '玄幻', 'fantasy', 4, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'romance', '言情', 'active', 'romance', '言情', 'romance', 5, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'scifi', '科幻', 'active', 'scifi', '科幻', 'scifi', 6, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'history', '历史', 'active', 'history', '历史', 'history', 7, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order, is_active)
SELECT dt.id, 'game', '游戏', 'active', 'game', '游戏', 'game', 8, true FROM dict_types dt WHERE dt.code = 'novel_category' ON CONFLICT DO NOTHING;

-- 修复完成
SELECT '字典表修复完成' AS status;
