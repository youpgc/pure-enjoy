-- ============================================================
-- 修复 dict_types 和 dict_items 表结构
-- 如果表已存在但缺少列，则添加列
-- ============================================================

-- 检查并添加 dict_types 表的列
DO $$
BEGIN
    -- 检查 type_code 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'type_code'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN type_code VARCHAR(50);
    END IF;

    -- 检查 type_name 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'type_name'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN type_name VARCHAR(100);
    END IF;

    -- 检查 description 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'description'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN description TEXT;
    END IF;

    -- 检查 sort_order 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'sort_order'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;

    -- 检查 is_system 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'is_system'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN is_system BOOLEAN DEFAULT false;
    END IF;

    -- 检查 is_active 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;

    -- 检查 updated_at 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_types' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE dict_types ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 检查并添加 dict_items 表的列
DO $$
BEGIN
    -- 检查 type_id 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'type_id'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN type_id UUID;
    END IF;

    -- 检查 item_code 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'item_code'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN item_code VARCHAR(50);
    END IF;

    -- 检查 item_name 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'item_name'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN item_name VARCHAR(100);
    END IF;

    -- 检查 item_value 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'item_value'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN item_value TEXT;
    END IF;

    -- 检查 sort_order 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'sort_order'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN sort_order INTEGER DEFAULT 0;
    END IF;

    -- 检查 is_default 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'is_default'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN is_default BOOLEAN DEFAULT false;
    END IF;

    -- 检查 is_active 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;

    -- 检查 extra_data 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'extra_data'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN extra_data JSONB;
    END IF;

    -- 检查 updated_at 列是否存在
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'dict_items' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE dict_items ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 添加外键约束（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'dict_items' AND constraint_name = 'dict_items_type_id_fkey'
    ) THEN
        ALTER TABLE dict_items 
        ADD CONSTRAINT dict_items_type_id_fkey 
        FOREIGN KEY (type_id) REFERENCES dict_types(id) ON DELETE CASCADE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- 外键添加失败则忽略
        NULL;
END $$;

-- 添加唯一约束（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'dict_types' AND constraint_name = 'dict_types_type_code_key'
    ) THEN
        ALTER TABLE dict_types ADD CONSTRAINT dict_types_type_code_key UNIQUE (type_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'dict_items' AND constraint_name = 'dict_items_type_id_item_code_key'
    ) THEN
        ALTER TABLE dict_items ADD CONSTRAINT dict_items_type_id_item_code_key UNIQUE (type_id, item_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;

-- 创建索引（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE indexname = 'idx_dict_items_type_id'
    ) THEN
        CREATE INDEX idx_dict_items_type_id ON dict_items(type_id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE indexname = 'idx_dict_items_item_code'
    ) THEN
        CREATE INDEX idx_dict_items_item_code ON dict_items(item_code);
    END IF;
END $$;

-- 修复完成
SELECT 'dict_types 和 dict_items 表结构修复完成' AS status;
