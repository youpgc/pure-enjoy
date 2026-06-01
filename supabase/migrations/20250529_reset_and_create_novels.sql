-- 清理并重建小说相关表（如果之前执行失败）
-- 注意：这会删除所有现有数据！

-- 1. 先删除章节表（因为有外键依赖）
DROP TABLE IF EXISTS public.chapters CASCADE;

-- 2. 删除小说表
DROP TABLE IF EXISTS public.novels CASCADE;

-- 3. 创建小说表
CREATE TABLE IF NOT EXISTS public.novels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(100),
    cover_url TEXT,
    description TEXT,
    category VARCHAR(50),
    source VARCHAR(50) DEFAULT 'original',
    source_url TEXT,
    tags TEXT[],
    chapter_count INTEGER DEFAULT 0,
    word_count INTEGER,
    status VARCHAR(20) DEFAULT 'ongoing',
    is_free BOOLEAN DEFAULT true,
    price DECIMAL(10, 2),
    rating DECIMAL(3, 2),
    read_count INTEGER DEFAULT 0,
    collect_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 创建章节表
CREATE TABLE IF NOT EXISTS public.chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    novel_id UUID NOT NULL REFERENCES public.novels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    chapter_num INTEGER NOT NULL,
    word_count INTEGER,
    is_free BOOLEAN DEFAULT true,
    price DECIMAL(10, 2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(novel_id, chapter_num)
);

-- 5. 创建索引
CREATE INDEX IF NOT EXISTS idx_novels_category ON public.novels(category);
CREATE INDEX IF NOT EXISTS idx_novels_status ON public.novels(status);
CREATE INDEX IF NOT EXISTS idx_novels_created_at ON public.novels(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chapters_novel_id ON public.chapters(novel_id);
CREATE INDEX IF NOT EXISTS idx_chapters_chapter_num ON public.chapters(chapter_num);

-- 6. 启用 RLS
ALTER TABLE public.novels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

-- 7. 创建 RLS 策略
CREATE POLICY "novels_select_policy" ON public.novels FOR SELECT USING (true);
CREATE POLICY "novels_insert_policy" ON public.novels FOR INSERT WITH CHECK (true);
CREATE POLICY "novels_update_policy" ON public.novels FOR UPDATE USING (true);
CREATE POLICY "novels_delete_policy" ON public.novels FOR DELETE USING (true);

CREATE POLICY "chapters_select_policy" ON public.chapters FOR SELECT USING (true);
CREATE POLICY "chapters_insert_policy" ON public.chapters FOR INSERT WITH CHECK (true);
CREATE POLICY "chapters_update_policy" ON public.chapters FOR UPDATE USING (true);
CREATE POLICY "chapters_delete_policy" ON public.chapters FOR DELETE USING (true);

-- 8. 创建触发器函数
CREATE OR REPLACE FUNCTION update_novel_chapter_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.novels 
        SET chapter_count = chapter_count + 1,
            updated_at = NOW()
        WHERE id = NEW.novel_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.novels 
        SET chapter_count = chapter_count - 1,
            updated_at = NOW()
        WHERE id = OLD.novel_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 9. 创建触发器
DROP TRIGGER IF EXISTS trigger_update_chapter_count ON public.chapters;
CREATE TRIGGER trigger_update_chapter_count
    AFTER INSERT OR DELETE ON public.chapters
    FOR EACH ROW
    EXECUTE FUNCTION update_novel_chapter_count();

-- 10. 插入示例小说数据
INSERT INTO public.novels (id, title, author, description, category, status, chapter_count, word_count, is_free, rating, cover_url)
VALUES 
('11111111-1111-1111-1111-111111111111'::uuid, '斗破苍穹', '天蚕土豆', '这里是斗气大陆，没有花俏艳丽的魔法，有的，仅仅是繁衍到巅峰的斗气！', '玄幻', 'completed', 3, 15000, true, 4.8, 'https://via.placeholder.com/300x400/FF6B6B/FFFFFF?text=斗破苍穹'),
('22222222-2222-2222-2222-222222222222'::uuid, '凡人修仙传', '忘语', '一个普通山村小子，偶然下进入到当地江湖小门派，成了一名记名弟子。', '仙侠', 'completed', 3, 18000, true, 4.9, 'https://via.placeholder.com/300x400/4ECDC4/FFFFFF?text=凡人修仙传'),
('33333333-3333-3333-3333-333333333333'::uuid, '诡秘之主', '爱潜水的乌贼', '蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？', '奇幻', 'completed', 3, 20000, true, 4.9, 'https://via.placeholder.com/300x400/9B59B6/FFFFFF?text=诡秘之主');

-- 11. 插入示例章节数据
INSERT INTO public.chapters (novel_id, title, content, chapter_num, word_count, is_free)
VALUES 
('11111111-1111-1111-1111-111111111111'::uuid, '第一章 陨落的天才', '萧炎，斗之力，三段！级别：低级！测验魔石碑之旁，一位中年男子，看了一眼碑上所显示出来的信息，语气漠然的将之公布了出来。', 1, 5000, true),
('11111111-1111-1111-1111-111111111111'::uuid, '第二章 斗气大陆', '月如银盘，漫天繁星。山崖之颠，萧炎斜躺在草地之上，嘴中叼中一根青草，微微嚼动，任由那淡淡的苦涩在嘴中弥漫开来。', 2, 5000, true),
('11111111-1111-1111-1111-111111111111'::uuid, '第三章 客人', '床榻之上，少年闭目盘腿而坐，双手在身前摆出奇异的手印，胸膛轻微起伏，一呼一吸间，形成完美的循环。', 3, 5000, true),
('22222222-2222-2222-2222-222222222222'::uuid, '第一章 山边小村', '二愣子睁大着双眼，直直望着茅草和烂泥糊成的黑屋顶，身上盖着的旧棉被，已呈深黄色。', 1, 6000, true),
('22222222-2222-2222-2222-222222222222'::uuid, '第二章 墨大夫', '韩立把手中的小刀舞成了一团白光，把面前的木桩砍得木屑横飞，他心里默默的数着数字。', 2, 6000, true),
('22222222-2222-2222-2222-222222222222'::uuid, '第三章 长春功', '韩立盘坐在床榻上，双目紧闭，双手结成一个奇异的手印，呼吸悠长而缓慢。', 3, 6000, true),
('33333333-3333-3333-3333-333333333333'::uuid, '第一章 绯红', '痛！好痛！头好痛！光怪陆离满是低语的梦境迅速支离破碎。', 1, 7000, true),
('33333333-3333-3333-3333-333333333333'::uuid, '第二章 笔记', '克莱恩靠在床头，手中捧着一杯温热的红茶，目光落在书桌上的那本笔记上。', 2, 7000, true),
('33333333-3333-3333-3333-333333333333'::uuid, '第三章 占卜', '克莱恩站在黑荆棘安保公司的门口，深吸一口气，整理了一下衣领，然后推门走了进去。', 3, 7000, true);
