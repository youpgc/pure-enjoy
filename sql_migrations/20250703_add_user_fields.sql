-- 2026-07-03: 新增用户统计字段，用于减少 App 端全量查询
-- 执行后需要在 Supabase Dashboard -> SQL Editor 中运行

-- 1. 连续打卡天数
ALTER TABLE users ADD COLUMN IF NOT EXISTS consecutive_checkin_days INTEGER DEFAULT 0;

-- 2. 有效积分（已发放未过期的积分总和）
ALTER TABLE users ADD COLUMN IF NOT EXISTS effective_points INTEGER DEFAULT 0;

-- 3. 可用积分（当前可使用的积分）
ALTER TABLE users ADD COLUMN IF NOT EXISTS available_points INTEGER DEFAULT 0;

-- 4. 即将过期积分（30天内过期的积分总和，由定时任务每日更新）
ALTER TABLE users ADD COLUMN IF NOT EXISTS expiring_points INTEGER DEFAULT 0;

-- 5. 最后打卡日期（用于判断连续打卡）
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_checkin_date DATE;

-- 6. 更新 RLS 策略：允许用户更新自己的统计字段
-- 注：如果已有 users 表的 update 策略，需要确认包含这些新字段
-- 建议策略：users.id = auth.uid()
