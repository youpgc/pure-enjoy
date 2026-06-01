-- ============================================================
-- 清空小说库数据
-- 执行日期: 2026-06-01
-- 说明: 清空后可通过管理后台或爬虫重新导入数据
-- ============================================================

-- 按依赖顺序删除数据（先删子表再删主表）

-- 1. 清空用户书架关联表
TRUNCATE TABLE user_novels CASCADE;

-- 2. 清空章节表
TRUNCATE TABLE novel_chapters CASCADE;

-- 3. 清空小说表
TRUNCATE TABLE novels CASCADE;

-- 验证结果
SELECT '小说库数据已清空' AS status;
SELECT 'novels 表行数: ' || COUNT(*) FROM novels;
SELECT 'novel_chapters 表行数: ' || COUNT(*) FROM novel_chapters;
SELECT 'user_novels 表行数: ' || COUNT(*) FROM user_novels;
