-- ============================================================
-- 创建 RPC 函数：get_user_dimension_stats
-- 用于管理后台 UserDimensionList 组件的后端聚合查询
-- 替代原来的前端全量拉取 + 内存聚合方案
-- ============================================================

-- 先删除旧函数（避免版本冲突）
DROP FUNCTION IF EXISTS get_user_dimension_stats(TEXT, TEXT[]);

CREATE OR REPLACE FUNCTION get_user_dimension_stats(
  p_table_name TEXT,
  p_user_ids TEXT[] DEFAULT NULL
)
RETURNS TABLE(
  user_id TEXT,
  count BIGINT,
  latest_record_at TIMESTAMPTZ
) AS $$
DECLARE
  v_sql TEXT;
BEGIN
  -- 构建基础查询
  v_sql := 'SELECT user_id, COUNT(*) AS count, MAX(created_at) AS latest_record_at FROM ' || quote_ident(p_table_name) || ' WHERE 1=1';

  -- 如果指定了用户ID列表，添加过滤条件
  IF p_user_ids IS NOT NULL THEN
    v_sql := v_sql || ' AND user_id = ANY(' || quote_literal(p_user_ids) || ')';
  END IF;

  -- 添加分组和排序
  v_sql := v_sql || ' GROUP BY user_id ORDER BY count DESC';

  -- 执行动态查询
  RETURN QUERY EXECUTE v_sql;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- 验证
SELECT 'get_user_dimension_stats 函数已创建' as status;
