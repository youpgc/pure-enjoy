-- ============================================================
-- 纯享App 数据库迁移脚本汇总
-- 生成日期: 2026-06-01
-- 版本: V1.9.1 及之前所有迁移
-- ============================================================

-- ============================================================
-- 1. 操作日志表 (V1.8.0+)
-- 用途: 管理后台记录用户操作日志
-- ============================================================

-- 操作日志表
CREATE TABLE IF NOT EXISTS operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100),
    username VARCHAR(100),
    action VARCHAR(50) NOT NULL,
    module VARCHAR(50) NOT NULL,
    description TEXT,
    ip_address VARCHAR(50),
    user_agent TEXT,
    request_data JSONB,
    response_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_operation_logs_user_id ON operation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_operation_logs_action ON operation_logs(action);
CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at ON operation_logs(created_at);

COMMENT ON TABLE operation_logs IS '操作日志表，用于管理后台记录用户操作';


-- ============================================================
-- 2. 小说章节表 (V1.8.7)
-- 用途: 小说阅读功能
-- ============================================================

-- 小说表
CREATE TABLE IF NOT EXISTS novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    author VARCHAR(100),
    description TEXT,
    cover_url TEXT,
    category VARCHAR(50),
    status VARCHAR(20) DEFAULT 'ongoing',
    total_chapters INTEGER DEFAULT 0,
    is_vip BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE novels IS '小说表';

-- 章节表
CREATE TABLE IF NOT EXISTS chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    chapter_num INTEGER NOT NULL,
    content TEXT,
    word_count INTEGER DEFAULT 0,
    is_vip BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE chapters IS '小说章节表';

-- 用户阅读进度表
CREATE TABLE IF NOT EXISTS user_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100) NOT NULL,
    novel_id UUID NOT NULL REFERENCES novels(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES chapters(id),
    last_chapter INTEGER DEFAULT 1,
    progress_percent INTEGER DEFAULT 0,
    is_in_bookshelf BOOLEAN DEFAULT false,
    last_read_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, novel_id)
);

COMMENT ON TABLE user_reading_progress IS '用户阅读进度表';

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_chapters_novel_id ON chapters(novel_id);
CREATE INDEX IF NOT EXISTS idx_chapters_chapter_num ON chapters(chapter_num);
CREATE INDEX IF NOT EXISTS idx_reading_progress_user_id ON user_reading_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_progress_novel_id ON user_reading_progress(novel_id);


-- ============================================================
-- 3. 字典管理表 (V1.8.8)
-- 用途: 数据字典服务，支持动态配置
-- 注意: 表可能已存在，使用 ALTER TABLE 添加缺失列
-- 实际 NOT NULL 列: dict_types(code,name,status) dict_items(type_id,code,label,status)
-- ============================================================

-- 字典类型表（如已存在则跳过）
CREATE TABLE IF NOT EXISTS dict_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE dict_types IS '字典类型表';

-- 字典项表（如已存在则跳过）
CREATE TABLE IF NOT EXISTS dict_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_id UUID NOT NULL REFERENCES dict_types(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    label VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    description TEXT,
    value TEXT,
    sort_order INTEGER DEFAULT 0,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    extra_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE dict_items IS '字典项表';

-- 添加 App 需要的新列（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'type_code') THEN
        ALTER TABLE dict_types ADD COLUMN type_code VARCHAR(50);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'type_name') THEN
        ALTER TABLE dict_types ADD COLUMN type_name VARCHAR(100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'is_system') THEN
        ALTER TABLE dict_types ADD COLUMN is_system BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_types' AND column_name = 'is_active') THEN
        ALTER TABLE dict_types ADD COLUMN is_active BOOLEAN DEFAULT true;
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
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dict_items' AND column_name = 'extra_data') THEN
        ALTER TABLE dict_items ADD COLUMN extra_data JSONB;
    END IF;
END $$;

-- 回填新列
UPDATE dict_types SET type_code = code, type_name = name WHERE type_code IS NULL;
UPDATE dict_items SET item_code = code, item_name = label WHERE item_code IS NULL;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_dict_items_type_id ON dict_items(type_id);
CREATE INDEX IF NOT EXISTS idx_dict_items_item_code ON dict_items(item_code);

-- 插入示例字典数据（使用实际列名 code/name/status）
INSERT INTO dict_types (code, name, status, type_code, type_name, description, is_system) VALUES
('expense_category', '消费分类', 'active', 'expense_category', '消费分类', '记账消费分类', true),
('mood_type', '心情类型', 'active', 'mood_type', '心情类型', '心情记录类型', true),
('novel_category', '小说分类', 'active', 'novel_category', '小说分类', '小说分类', true)
ON CONFLICT (code) DO UPDATE SET
    type_code = EXCLUDED.type_code,
    type_name = EXCLUDED.type_name,
    description = EXCLUDED.description,
    is_system = EXCLUDED.is_system;

-- 消费分类
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'food', '餐饮', 'active', 'food', '餐饮', 'food', 1 FROM dict_types WHERE code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'transport', '交通', 'active', 'transport', '交通', 'transport', 2 FROM dict_types WHERE code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'shopping', '购物', 'active', 'shopping', '购物', 'shopping', 3 FROM dict_types WHERE code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'entertainment', '娱乐', 'active', 'entertainment', '娱乐', 'entertainment', 4 FROM dict_types WHERE code = 'expense_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'housing', '居住', 'active', 'housing', '居住', 'housing', 5 FROM dict_types WHERE code = 'expense_category'
ON CONFLICT DO NOTHING;

-- 心情类型
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'happy', '开心', 'active', 'happy', '开心', 'happy', 1 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'excited', '兴奋', 'active', 'excited', '兴奋', 'excited', 2 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'calm', '平静', 'active', 'calm', '平静', 'calm', 3 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'tired', '疲惫', 'active', 'tired', '疲惫', 'tired', 4 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'sad', '难过', 'active', 'sad', '难过', 'sad', 5 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'angry', '生气', 'active', 'angry', '生气', 'angry', 6 FROM dict_types WHERE code = 'mood_type'
ON CONFLICT DO NOTHING;

-- 小说分类
INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'xianxia', '仙侠', 'active', 'xianxia', '仙侠', 'xianxia', 1 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'wuxia', '武侠', 'active', 'wuxia', '武侠', 'wuxia', 2 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'urban', '都市', 'active', 'urban', '都市', 'urban', 3 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'fantasy', '玄幻', 'active', 'fantasy', '玄幻', 'fantasy', 4 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'romance', '言情', 'active', 'romance', '言情', 'romance', 5 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'scifi', '科幻', 'active', 'scifi', '科幻', 'scifi', 6 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'history', '历史', 'active', 'history', '历史', 'history', 7 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;

INSERT INTO dict_items (type_id, code, label, status, item_code, item_name, item_value, sort_order) 
SELECT id, 'game', '游戏', 'active', 'game', '游戏', 'game', 8 FROM dict_types WHERE code = 'novel_category'
ON CONFLICT DO NOTHING;


-- ============================================================
-- 4. 习惯打卡提醒字段 (V1.9.1)
-- 用途: 本地通知提醒功能
-- ============================================================

-- 添加习惯提醒字段
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS reminder_enabled BOOLEAN DEFAULT false;
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS reminder_hour INTEGER;
ALTER TABLE user_habits ADD COLUMN IF NOT EXISTS reminder_minute INTEGER;

COMMENT ON COLUMN user_habits.reminder_enabled IS '是否开启每日打卡提醒';
COMMENT ON COLUMN user_habits.reminder_hour IS '提醒时间-小时 (0-23)';
COMMENT ON COLUMN user_habits.reminder_minute IS '提醒时间-分钟 (0-59)';


-- ============================================================
-- 5. 插入示例小说数据 (可选)
-- ============================================================

-- 示例小说1: 斗破苍穹
INSERT INTO novels (id, title, author, description, category, status, total_chapters, is_vip)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    '斗破苍穹',
    '天蚕土豆',
    '这里是属于斗气的世界，没有花俏艳丽的魔法，有的，仅仅是繁衍到巅峰的斗气！',
    'fantasy',
    'completed',
    3,
    false
) ON CONFLICT (id) DO NOTHING;

-- 示例章节
INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('21111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', '第一章 陨落的天才', 1, 
'望着测验魔石碑上面闪亮得甚至有些刺眼的五个大字，少年面无表情，唇角有着一抹自嘲，紧握的手掌，因为大力，而导致略微尖锐的指甲深深的刺进了掌心之中，带来一阵阵钻心的疼痛。

萧炎，斗之力，三段！级别：低级！

测验魔石碑之旁，一位中年男子，看了一眼碑上所显示出来的信息，语气漠然的将之公布了出来。

中年男子话刚刚脱口，便是不出意外的在人头汹涌的广场上带起了一阵嘲讽的骚动。

三段？嘿嘿，果然不出我所料，这个天才这一年又是在原地踏步！

哎，这废物真是把家族的脸都给丢光了。', 500)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('21111111-1111-1111-1111-111111111112', '11111111-1111-1111-1111-111111111111', '第二章 斗气大陆', 2,
'斗气大陆，辽阔无边，万族林立，宗派无数。

在这片大陆上，斗气是唯一的修炼方式。斗气修炼到极致，可开山裂石，翻江倒海，甚至破碎虚空，成就无上斗帝。

斗气大陆将斗气修为划分为九个等级：斗者、斗师、大斗师、斗灵、斗王、斗皇、斗宗、斗尊、斗圣，以及传说中的斗帝。

每个等级又分为九星，从一星到九星，循序渐进。', 450)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('21111111-1111-1111-1111-111111111113', '11111111-1111-1111-1111-111111111111', '第三章 客人', 3,
'月色如水，洒落在萧家后山。

萧炎独自坐在山顶，望着远处灯火通明的萧家大院，心中五味杂陈。

三年前，他还是萧家最耀眼的天才，十二岁便成为斗者，震惊整个乌坦城。可如今，他却沦为人人嘲笑的废物，连续三年斗之气停留在三段，无法寸进。

这一切，都源于那枚神秘的戒指。', 480)
ON CONFLICT (id) DO NOTHING;

-- 示例小说2: 全职高手
INSERT INTO novels (id, title, author, description, category, status, total_chapters, is_vip)
VALUES (
    '22222222-2222-2222-2222-222222222222',
    '全职高手',
    '蝴蝶蓝',
    '网游荣耀中被誉为教科书级别的顶尖高手，因为种种原因遭到俱乐部的驱逐，离开职业圈的他寄身于一家网吧成了一个小小的网管，但是，拥有十年游戏经验的他，在荣耀新开的第十区重新投入了游戏，带着对往昔的回忆，和一把未完成的自制武器，开始了重返巅峰之路。',
    'game',
    'completed',
    3,
    false
) ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('22222222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222222', '第一章 被驱逐的高手', 1,
'叶秋，荣耀职业联盟初代选手，荣耀联赛第1~3、10赛季总冠军得主、第4赛季亚军得主。荣耀职业联赛历史上第一位也是唯一一位三连冠王朝战队缔造者，荣获4届最有价值选手（MVP），两获输出之星、一次一击必杀、一次单挑之王。

然而今天，这位荣耀圈的传奇人物，却被嘉世俱乐部扫地出门。', 520)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('22222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', '第二章 C区47号', 2,
'兴欣网吧。

叶修拖着行李箱，站在网吧门口，抬头看了看招牌。

就是这里了。

他推开玻璃门，走了进去。网吧里弥漫着烟味和泡面的味道，键盘敲击声此起彼伏。

老板，你们这招人吗？叶修走到前台问道。', 460)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('22222222-2222-2222-2222-222222222223', '22222222-2222-2222-2222-222222222222', '第三章 君莫笑', 3,
'荣耀第十区开服。

叶修坐在兴欣网吧的角落里，登录了自己的账号。

ID：君莫笑。

这是一个全新的开始。没有斗神一叶之秋的光环，没有三连冠的荣耀，只有一个普通的账号，和一颗永不言败的心。

新手村，君莫笑提着一把新手剑，开始了他的新征程。', 490)
ON CONFLICT (id) DO NOTHING;

-- 示例小说3: 凡人修仙传
INSERT INTO novels (id, title, author, description, category, status, total_chapters, is_vip)
VALUES (
    '33333333-3333-3333-3333-333333333333',
    '凡人修仙传',
    '忘语',
    '一个普通山村小子，偶然下进入到当地江湖小门派，成了一名记名弟子。他以这样身份，如何在门派中立足，如何以平庸的资质进入到修仙者的行列，从而笑傲三界之中！',
    'xianxia',
    'completed',
    3,
    false
) ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('33333333-3333-3333-3333-333333333331', '33333333-3333-3333-3333-333333333333', '第一章 七玄门', 1,
'韩立，一个普通的山村少年。

他出生在天南越国镜州青牛镇五里沟，家境贫寒，父母都是普通的农民。

十岁那年，村里来了两位仙人，说是要招收有灵根的弟子。韩立被检测出具有四属性伪灵根，勉强符合修仙条件，被带入了七玄门。', 510)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('33333333-3333-3333-3333-333333333332', '33333333-3333-3333-3333-333333333333', '第二章 墨大夫', 2,
'七玄门神手谷。

韩立被分配到了神手谷，成为墨大夫的弟子。

墨大夫是一位医术高超的神医，但他收徒的目的并不单纯。韩立虽然年幼，却也感觉到了这位师父身上隐藏的阴冷气息。

在神手谷，韩立开始了他的修仙之路。', 470)
ON CONFLICT (id) DO NOTHING;

INSERT INTO chapters (id, novel_id, title, chapter_num, content, word_count) VALUES
('33333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', '第三章 长春功', 3,
'墨大夫终于露出了真面目。

他修炼了一种邪功，需要夺舍有灵根的弟子才能延续生命。韩立成为了他的目标。

然而，墨大夫万万没有想到，韩立早已暗中修炼了《长春功》，并且已经突破到了第四层。

夺舍失败，墨大夫魂飞魄散，而韩立则获得了墨大夫留下的所有遗产，包括珍贵的丹药和法器。', 530)
ON CONFLICT (id) DO NOTHING;


-- ============================================================
-- 迁移完成
-- ============================================================

SELECT '数据库迁移完成！' AS status;
SELECT '已创建/更新以下表:' AS info;
SELECT '- operation_logs (操作日志表)' AS table_name;
SELECT '- novels (小说表)' AS table_name;
SELECT '- chapters (章节表)' AS table_name;
SELECT '- user_reading_progress (阅读进度表)' AS table_name;
SELECT '- dict_types (字典类型表)' AS table_name;
SELECT '- dict_items (字典项表)' AS table_name;
SELECT '- user_habits (习惯表 - 新增提醒字段)' AS table_name;
