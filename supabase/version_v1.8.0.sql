-- ============================================================
-- V1.8.0 版本同步 SQL
-- 执行时间: 2026-05-29
-- 版本: 1.8.0+32
-- 说明: 三端对齐修复版本
-- ============================================================

-- 1. 先将其他已发布版本下架
UPDATE app_versions
SET status = 'revoked', revoked_at = NOW()
WHERE status = 'released';

-- 2. 删除可能存在的同版本记录（幂等性）
DELETE FROM app_versions
WHERE version = '1.8.0' AND build_number = 32;

-- 3. 插入新版本记录
-- 注意: apk_url 需要在 GitHub Actions 构建完成后填写
INSERT INTO app_versions (version, build_number, release_type, release_notes, apk_url, apk_size, status, released_at)
VALUES (
    '1.8.0',
    32,
    'feature',
    '三端对齐修复版本 - App端/管理端/Supabase 字段名统一',
    'https://mhdrbjpqmzswswoazwjg.supabase.co/storage/v1/object/public/apk-releases/pure-enjoy-v1.8.0+32.apk',
    0,  -- 文件大小在构建后更新
    'released',
    NOW()
);

-- 4. 验证插入结果
SELECT id, version, build_number, release_type, status, released_at
FROM app_versions
WHERE version = '1.8.0' AND build_number = 32;
