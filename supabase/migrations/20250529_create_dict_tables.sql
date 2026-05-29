-- =============================================
-- 数据字典表
-- 用于管理下拉选项和数据枚举
-- =============================================

-- 字典类型表
CREATE TABLE IF NOT EXISTS public.dict_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,       -- 类型编码，如 expense_category, mood_type
    name VARCHAR(100) NOT NULL,              -- 类型名称，如 消费分类, 心情类型
    description TEXT,                         -- 描述
    sort_order INTEGER DEFAULT 0,            -- 排序
    is_system BOOLEAN DEFAULT false,          -- 是否系统内置（不可删除）
    status VARCHAR(20) DEFAULT 'active',      -- active, disabled
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 字典项表
CREATE TABLE IF NOT EXISTS public.dict_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_id UUID NOT NULL REFERENCES public.dict_types(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,               -- 项编码，如 food, happy
    label VARCHAR(100) NOT NULL,              -- 显示名称，如 餐饮, 开心
    value VARCHAR(255),                      -- 扩展值（如颜色值、图标名等）
    extra JSONB,                              -- 扩展字段（如 emoji、颜色等）
    sort_order INTEGER DEFAULT 0,             -- 排序
    is_default BOOLEAN DEFAULT false,          -- 是否默认选项
    status VARCHAR(20) DEFAULT 'active',      -- active, disabled
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(type_id, code)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_dict_types_code ON public.dict_types(code);
CREATE INDEX IF NOT EXISTS idx_dict_items_type_id ON public.dict_items(type_id);
CREATE INDEX IF NOT EXISTS idx_dict_items_sort ON public.dict_items(type_id, sort_order);

-- RLS：所有人可读
ALTER TABLE public.dict_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dict_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dict_types_select" ON public.dict_types FOR SELECT USING (true);
CREATE POLICY "dict_items_select" ON public.dict_items FOR SELECT USING (true);

-- 管理员可写（通过 user_id 关联或 service_role）
CREATE POLICY "dict_types_insert" ON public.dict_types
    FOR INSERT WITH CHECK (true);
CREATE POLICY "dict_types_update" ON public.dict_types
    FOR UPDATE USING (true);
CREATE POLICY "dict_types_delete" ON public.dict_types
    FOR DELETE USING (is_system = false);

CREATE POLICY "dict_items_insert" ON public.dict_items
    FOR INSERT WITH CHECK (true);
CREATE POLICY "dict_items_update" ON public.dict_items
    FOR UPDATE USING (true);
CREATE POLICY "dict_items_delete" ON public.dict_items
    FOR DELETE USING (true);

-- =============================================
-- 初始化字典数据
-- =============================================

-- 1. 消费分类
INSERT INTO public.dict_types (id, code, name, description, sort_order, is_system) VALUES
('a0000001-0000-0000-0000-000000000001', 'expense_category', '消费分类', '消费记录的分类选项', 1, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.dict_items (type_id, code, label, value, extra, sort_order, is_default) VALUES
('a0000001-0000-0000-0000-000000000001', 'food', '餐饮', 'restaurant', '{"icon": "restaurant"}', 1, true),
('a0000001-0000-0000-0000-000000000001', 'transport', '交通', 'directions_car', '{"icon": "directions_car"}', 2, false),
('a0000001-0000-0000-0000-000000000001', 'shopping', '购物', 'shopping_bag', '{"icon": "shopping_bag"}', 3, false),
('a0000001-0000-0000-0000-000000000001', 'entertainment', '娱乐', 'movie', '{"icon": "movie"}', 4, false),
('a0000001-0000-0000-0000-000000000001', 'health', '医疗', 'local_hospital', '{"icon": "local_hospital"}', 5, false),
('a0000001-0000-0000-0000-000000000001', 'education', '教育', 'school', '{"icon": "school"}', 6, false),
('a0000001-0000-0000-0000-000000000001', 'other', '其他', 'more_horiz', '{"icon": "more_horiz"}', 99, false)
ON CONFLICT (type_id, code) DO NOTHING;

-- 2. 心情类型
INSERT INTO public.dict_types (id, code, name, description, sort_order, is_system) VALUES
('a0000001-0000-0000-0000-000000000002', 'mood_type', '心情类型', '心情日记的心情选项', 2, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.dict_items (type_id, code, label, value, extra, sort_order, is_default) VALUES
('a0000001-0000-0000-0000-000000000002', 'happy', '开心', '9', '{"emoji": "😊", "color": 4294967043}', 1, true),
('a0000001-0000-0000-0000-000000000002', 'excited', '兴奋', '10', '{"emoji": "🤩", "color": 4294948863}', 2, false),
('a0000001-0000-0000-0000-000000000002', 'calm', '平静', '7', '{"emoji": "😌", "color": 4283215671}', 3, false),
('a0000001-0000-0000-0000-000000000002', 'neutral', '一般', '5', '{"emoji": "😐", "color": 4285013547}', 4, false),
('a0000001-0000-0000-0000-000000000002', 'sad', '难过', '3', '{"emoji": "😢", "color": 4282527879}', 5, false),
('a0000001-0000-0000-0000-000000000002', 'anxious', '焦虑', '4', '{"emoji": "😰", "color": 4287295487}', 6, false),
('a0000001-0000-0000-0000-000000000002', 'angry', '生气', '2', '{"emoji": "😤", "color": 4294927871}', 7, false),
('a0000001-0000-0000-0000-000000000002', 'tired', '疲惫', '3', '{"emoji": "😴", "color": 4289506560}', 8, false)
ON CONFLICT (type_id, code) DO NOTHING;

-- 3. 小说分类
INSERT INTO public.dict_types (id, code, name, description, sort_order, is_system) VALUES
('a0000001-0000-0000-0000-000000000003', 'novel_category', '小说分类', '小说的分类选项', 3, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.dict_items (type_id, code, label, extra, sort_order, is_default) VALUES
('a0000001-0000-0000-0000-000000000003', 'xuanhuan', '玄幻', NULL, 1, true),
('a0000001-0000-0000-0000-000000000003', 'xianxia', '仙侠', NULL, 2, false),
('a0000001-0000-0000-0000-000000000003', 'dushi', '都市', NULL, 3, false),
('a0000001-0000-0000-0000-000000000003', 'lishi', '历史', NULL, 4, false),
('a0000001-0000-0000-0000-000000000003', 'wuxia', '武侠', NULL, 5, false),
('a0000001-0000-0000-0000-000000000003', 'kehuan', '科幻', NULL, 6, false),
('a0000001-0000-0000-0000-000000000003', 'youxi', '游戏', NULL, 7, false),
('a0000001-0000-0000-0000-000000000003', 'xuanyi', '悬疑', NULL, 8, false),
('a0000001-0000-0000-0000-000000000003', 'lingyi', '灵异', NULL, 9, false),
('a0000001-0000-0000-0000-000000000003', 'yanqing', '言情', NULL, 10, false),
('a0000001-0000-0000-0000-000000000003', 'qita', '其他', NULL, 99, false)
ON CONFLICT (type_id, code) DO NOTHING;

-- 4. 习惯频率
INSERT INTO public.dict_types (id, code, name, description, sort_order, is_system) VALUES
('a0000001-0000-0000-0000-000000000004', 'habit_frequency', '习惯频率', '习惯打卡的频率选项', 4, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.dict_items (type_id, code, label, extra, sort_order, is_default) VALUES
('a0000001-0000-0000-0000-000000000004', 'daily', '每天', NULL, 1, true),
('a0000001-0000-0000-0000-000000000004', 'weekly', '每周', NULL, 2, false),
('a0000001-0000-0000-0000-000000000004', 'monthly', '每月', NULL, 3, false),
('a0000001-0000-0000-0000-000000000004', 'custom', '自定义', NULL, 99, false)
ON CONFLICT (type_id, code) DO NOTHING;

-- 5. 习惯颜色
INSERT INTO public.dict_types (id, code, name, description, sort_order, is_system) VALUES
('a0000001-0000-0000-0000-000000000005', 'habit_color', '习惯颜色', '习惯卡片的颜色选项', 5, true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.dict_items (type_id, code, label, value, extra, sort_order, is_default) VALUES
('a0000001-0000-0000-0000-000000000005', 'red', '红色', '0xFFEF4444', '{"color": 4294191744}', 1, false),
('a0000001-0000-0000-0000-000000000005', 'orange', '橙色', '0xFFF97316', '{"color": 4286513406}', 2, false),
('a0000001-0000-0000-0000-000000000005', 'yellow', '黄色', '0xFFEAB308', '{"color": 4289309576}', 3, false),
('a0000001-0000-0000-0000-000000000005', 'green', '绿色', '0xFF22C55E', '{"color": 4283214078}', 4, false),
('a0000001-0000-0000-0000-000000000005', 'blue', '蓝色', '0xFF3B82F6', '{"color": 4280391414}', 5, true),
('a0000001-0000-0000-0000-000000000005', 'purple', '紫色', '0xFF8B5CF6', '{"color": 4285538870}', 6, false),
('a0000001-0000-0000-0000-000000000005', 'pink', '粉色', '0xFFEC4899', '{"color": 4291714473}', 7, false)
ON CONFLICT (type_id, code) DO NOTHING;
