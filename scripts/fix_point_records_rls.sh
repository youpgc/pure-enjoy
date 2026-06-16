#!/bin/bash
# 修复 point_records 和 users 表 RLS 策略
# 用法: ./scripts/fix_point_records_rls.sh

set -e

PROJECT_REF="mhdrbjpqmzswswoazwjg"
DB_PASSWORD="1@youpgc@VIP"
DB_HOST="db.${PROJECT_REF}.supabase.co"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="postgres"

echo "🔧 修复 point_records 和 users 表 RLS 策略..."

PGPASSWORD="$DB_PASSWORD" psql \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -f ../sql/fix_point_records_rls.sql

echo "✅ RLS 策略修复完成"

# 验证：测试 App 端查询（带 x-user-id）
echo ""
echo "🧪 验证 App 端查询（带 x-user-id）..."
VERIFY_APP=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/point_records?select=id,user_id,type,amount&limit=1" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "x-user-id: U17789397932M453781")

echo "App query (with x-user-id): $VERIFY_APP"

# 验证：测试管理后台查询（带 admin x-user-id）
echo ""
echo "🧪 验证管理后台查询（带 admin x-user-id）..."
VERIFY_ADMIN=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/point_records?select=id,user_id,type,amount&limit=1" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "x-user-id: admin_user_id_here")

echo "Admin query (with x-user-id): $VERIFY_ADMIN"

# 验证：测试未授权查询（不带 x-user-id）
echo ""
echo "🧪 验证未授权查询（不带 x-user-id）..."
VERIFY_NO_AUTH=$(curl -s "https://${PROJECT_REF}.supabase.co/rest/v1/point_records?select=id,user_id,type,amount&limit=1" \
  -H "apikey: sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6" \
  -H "Authorization: Bearer sb_publishable_wFx9tlxImVfEpRN4NMkS1g_QOm64aj6")

echo "No auth query (no x-user-id): $VERIFY_NO_AUTH"
