#!/bin/bash
# 修复 user_feedback 表 RLS 策略
# 用法: ./scripts/fix_feedback_rls.sh

set -e

PROJECT_REF="mhdrbjpqmzswswoazwjg"
DB_PASSWORD="1@youpgc@VIP"
DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="postgres"

echo "🔧 修复 user_feedback RLS 策略..."

PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c "
DO \$\$ DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'user_feedback' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON user_feedback', r.policyname);
  END LOOP;
END \$\$;

-- 允许匿名查询（管理后台使用）
CREATE POLICY \"user_feedback_select\" ON user_feedback FOR SELECT USING (true);
CREATE POLICY \"user_feedback_insert\" ON user_feedback FOR INSERT WITH CHECK (true);
CREATE POLICY \"user_feedback_update\" ON user_feedback FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY \"user_feedback_delete\" ON user_feedback FOR DELETE USING (true);
"

echo "✅ user_feedback RLS 策略修复完成"

# 验证
VERIFY=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/user_feedback?select=id&limit=1" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6")

echo "验证查询: $VERIFY"
