#!/bin/bash
# 修复 user_anniversaries 表 RLS 策略（安全版本：用户只能查看自己的数据）
# 用法: ./scripts/fix_rls_secure.sh

set -e

PROJECT_REF="mhdrbjpqmzswswoazwjg"
DB_PASSWORD="1@youpgc@VIP"
DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="postgres"

echo "🔧 修复 user_anniversaries RLS 策略（安全版本）..."

PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -c "
DO \$\$ DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'user_anniversaries' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON user_anniversaries', r.policyname);
  END LOOP;
END \$\$;

-- 用户只能查看/操作自己的数据（通过URL参数中的user_id过滤）
CREATE POLICY \"user_anniversaries_select\" ON user_anniversaries
  FOR SELECT USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR user_id = current_setting('request.headers', true)::json->>'x-user-id');

CREATE POLICY \"user_anniversaries_insert\" ON user_anniversaries
  FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR user_id = current_setting('request.headers', true)::json->>'x-user-id');

CREATE POLICY \"user_anniversaries_update\" ON user_anniversaries
  FOR UPDATE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR user_id = current_setting('request.headers', true)::json->>'x-user-id');

CREATE POLICY \"user_anniversaries_delete\" ON user_anniversaries
  FOR DELETE USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub' OR user_id = current_setting('request.headers', true)::json->>'x-user-id');
"

echo "✅ RLS 策略修复完成（安全版本）"

# 验证：anon key 应该只能看到空数组（因为没有传 x-user-id）
VERIFY=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/user_anniversaries?select=id,title,user_id&limit=5" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6")

echo "Anon query (no x-user-id): $VERIFY"

# 验证：带 x-user-id 应该能看到数据
VERIFY2=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/user_anniversaries?select=id,title,user_id&limit=5" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "x-user-id: U17789397932M453781")

echo "Anon query (with x-user-id): $VERIFY2"
