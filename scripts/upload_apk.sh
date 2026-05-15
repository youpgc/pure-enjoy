#!/bin/bash

# =============================================================================
# APK 上传脚本
# 用于手动上传 APK 到 Supabase Storage 并创建版本记录
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# 帮助信息
# =============================================================================
show_help() {
    echo -e "${BLUE}APK 上传工具${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -f, --file <路径>        APK 文件路径 (必需)"
    echo "  -v, --version <版本>      版本号, 如 1.0.0 (必需)"
    echo "  -b, --build <构建号>      构建号, 如 1 (必需)"
    echo "  -n, --notes <说明>        更新说明 (可选)"
    echo "  -F, --force               是否强制更新 (可选, 默认 false)"
    echo "  -p, --platform <平台>     平台 (android/ios, 默认 android)"
    echo "  -h, --help               显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  SUPABASE_URL             Supabase 项目 URL"
    echo "  SUPABASE_SERVICE_KEY     Supabase Service Role Key"
    echo "  SUPABASE_ANON_KEY        Supabase Anon Key (可选)"
    echo ""
    echo "示例:"
    echo "  $0 -f build/app.apk -v 1.0.0 -b 1"
    echo "  $0 -f build/app.apk -v 1.0.0 -b 1 -n '修复了一些bug' -F"
}

# =============================================================================
# 参数解析
# =============================================================================
APK_FILE=""
VERSION=""
BUILD_NUMBER=""
RELEASE_NOTES=""
IS_FORCE_UPDATE="false"
PLATFORM="android"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            APK_FILE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_NUMBER="$2"
            shift 2
            ;;
        -n|--notes)
            RELEASE_NOTES="$2"
            shift 2
            ;;
        -F|--force)
            IS_FORCE_UPDATE="true"
            shift
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# 验证参数
# =============================================================================
if [ -z "$APK_FILE" ] || [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
    echo -e "${RED}错误: 缺少必需参数${NC}"
    show_help
    exit 1
fi

if [ ! -f "$APK_FILE" ]; then
    echo -e "${RED}错误: APK 文件不存在: $APK_FILE${NC}"
    exit 1
fi

# =============================================================================
# 检查环境变量
# =============================================================================
if [ -z "$SUPABASE_URL" ]; then
    echo -e "${RED}错误: 未设置 SUPABASE_URL 环境变量${NC}"
    exit 1
fi

if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo -e "${RED}错误: 未设置 SUPABASE_SERVICE_KEY 环境变量${NC}"
    exit 1
fi

# =============================================================================
# 提取项目 ID
# =============================================================================
PROJECT_ID=$(echo "$SUPABASE_URL" | sed -E 's/https:\/\/([^.]+).supabase.co/\1/')
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}错误: 无法从 SUPABASE_URL 提取项目 ID${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       APK 上传工具${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# =============================================================================
# 文件信息
# =============================================================================
FILE_NAME=$(basename "$APK_FILE")
FILE_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || stat -f%z "$APK_FILE" 2>/dev/null)
CHECKSUM=$(sha256sum "$APK_FILE" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$APK_FILE" 2>/dev/null | awk '{print $1}')
NEW_FILE_NAME="pure-enjoy-v${VERSION}+${BUILD_NUMBER}.apk"

echo -e "${YELLOW}文件信息:${NC}"
echo "  原始文件名: $FILE_NAME"
echo "  新文件名: $NEW_FILE_NAME"
echo "  文件大小: $(numfmt --to=iec $FILE_SIZE 2>/dev/null || echo $FILE_SIZE bytes)"
echo "  SHA256: $CHECKSUM"
echo ""

echo -e "${YELLOW}版本信息:${NC}"
echo "  版本号: $VERSION"
echo "  构建号: $BUILD_NUMBER"
echo "  平台: $PLATFORM"
echo "  强制更新: $IS_FORCE_UPDATE"
echo "  更新说明: ${RELEASE_NOTES:-'(无)'}"
echo ""

echo -e "${YELLOW}Supabase 配置:${NC}"
echo "  项目 ID: $PROJECT_ID"
echo "  URL: $SUPABASE_URL"
echo ""

# =============================================================================
# 检查依赖
# =============================================================================
echo -e "${BLUE}检查依赖...${NC}"

# 检查 curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}错误: 未安装 curl${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 依赖检查通过${NC}"
echo ""

# =============================================================================
# 上传文件到 Supabase Storage
# =============================================================================
echo -e "${BLUE}上传 APK 到 Supabase Storage...${NC}"

# 方法 1: 使用 Storage API 直接上传
echo "  正在上传文件..."

UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SUPABASE_URL}/storage/v1/object/apk-releases/${NEW_FILE_NAME}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --data-binary "@$APK_FILE" \
    2>&1)

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
    echo -e "${RED}✗ 上传失败 (HTTP $HTTP_CODE)${NC}"
    echo "响应: $RESPONSE_BODY"
    exit 1
fi

echo -e "${GREEN}✓ 文件上传成功${NC}"

# 构建下载 URL
DOWNLOAD_URL="${SUPABASE_URL}/storage/v1/object/public/apk-releases/${NEW_FILE_NAME}"
echo "  下载链接: $DOWNLOAD_URL"
echo ""

# =============================================================================
# 创建版本记录
# =============================================================================
echo -e "${BLUE}创建版本记录...${NC}"

# 转义更新说明中的特殊字符
ESCAPED_NOTES=$(echo "$RELEASE_NOTES" | sed 's/"/\\"/g' | sed 's/\n/\\n/g')

INSERT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${SUPABASE_URL}/rest/v1/app_versions" \
    -H "apikey: ${SUPABASE_SERVICE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=representation" \
    -d "{
        \"version\": \"${VERSION}\",
        \"build_number\": ${BUILD_NUMBER},
        \"download_url\": \"${DOWNLOAD_URL}\",
        \"file_size\": ${FILE_SIZE},
        \"checksum\": \"${CHECKSUM}\",
        \"release_notes\": \"${ESCAPED_NOTES}\",
        \"is_force_update\": ${IS_FORCE_UPDATE},
        \"is_active\": true,
        \"platform\": \"${PLATFORM}\",
        \"file_name\": \"${NEW_FILE_NAME}\",
        \"created_by\": \"manual-upload\"
    }" \
    2>&1)

HTTP_CODE=$(echo "$INSERT_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$INSERT_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
    echo -e "${RED}✗ 创建版本记录失败 (HTTP $HTTP_CODE)${NC}"
    echo "响应: $RESPONSE_BODY"
    echo ""
    echo -e "${YELLOW}注意: 文件已上传成功, 但版本记录创建失败${NC}"
    echo "      请手动在数据库中创建版本记录"
    exit 1
fi

echo -e "${GREEN}✓ 版本记录创建成功${NC}"
echo ""

# =============================================================================
# 完成
# =============================================================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}       上传完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}版本信息:${NC}"
echo "  版本号: $VERSION"
echo "  构建号: $BUILD_NUMBER"
echo "  文件大小: $(numfmt --to=iec $FILE_SIZE 2>/dev/null || echo $FILE_SIZE bytes)"
echo "  SHA256: $CHECKSUM"
echo ""
echo -e "${YELLOW}下载信息:${NC}"
echo "  下载链接: $DOWNLOAD_URL"
echo "  二维码: https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$(echo "$DOWNLOAD_URL" | sed 's/&/%26/g')"
echo ""

# 可选: 生成二维码
if command -v qrencode &> /dev/null; then
    echo -e "${BLUE}二维码:${NC}"
    qrencode -t ANSIUTF8 "$DOWNLOAD_URL"
fi

exit 0
