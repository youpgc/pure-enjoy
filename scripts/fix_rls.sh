#!/bin/bash
# 修复 user_anniversaries 表 RLS 策略
# 用法: ./scripts/fix_rls.sh

set -e

PROJECT_REF="mhdrbjpqmzswswoazwjg"
DB_PASSWORD="1@youpgc@VIP"
DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="postgres"

echo "🔧 修复 user_anniversaries RLS 策略..."

# 使用 psql 连接 Supabase 数据库
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

CREATE POLICY \"user_anniversaries_select\" ON user_anniversaries FOR SELECT USING (true);
CREATE POLICY \"user_anniversaries_insert\" ON user_anniversaries FOR INSERT WITH CHECK (true);
CREATE POLICY \"user_anniversaries_update\" ON user_anniversaries FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY \"user_anniversaries_delete\" ON user_anniversaries FOR DELETE USING (true);
"

echo "✅ RLS 策略修复完成"

# 验证
VERIFY=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://${PROJECT_REF}.supabase.co/rest/v1/user_anniversaries?select=id&limit=1" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6")

if [ "$VERIFY" = "200" ]; then
  echo "✅ 验证通过: anon key 可正常查询"
else
  echo "❌ 验证失败: HTTP $VERIFY"
fi
