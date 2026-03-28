#!/bin/bash
# ============================================================
# 同步上游数据库中匹配指定 community 名称的表到本地
# 用法: ./sync_community_tables.sh <community_name>
# 示例: ./sync_community_tables.sh bj
#        → 同步所有形如 xxx_bj_xxx 的表
# ============================================================

# ========== 上游数据库配置（自行修改） ==========
UPSTREAM_HOST=""       # 上游数据库 IP
UPSTREAM_PORT="5432"                 # 上游端口
UPSTREAM_USER=""             # 上游用户名
UPSTREAM_PASS=""        # 上游密码
UPSTREAM_DB=""                # 上游数据库名

# ========== 本地数据库配置 ==========
LOCAL_HOST="localhost"
LOCAL_PORT="5432"
LOCAL_USER="<db user>"
LOCAL_PASS="<password>"
LOCAL_DB="<db name>"

# ============================================================

# 读取 community 参数
COMMUNITY="${1:-}"
if [ -z "$COMMUNITY" ]; then
  echo "用法: $0 <community_name>"
  echo "示例: $0 bj"
  exit 1
fi

# 匹配 xxx_<community>_xxx 格式的表
TABLE_PATTERN="%_${COMMUNITY}_%"

export PGPASSWORD="$UPSTREAM_PASS"

echo ">>> community: $COMMUNITY"
echo ">>> 匹配模式: $TABLE_PATTERN"
echo ">>> 正在从上游获取匹配的表列表..."

TABLES=$(psql -h "$UPSTREAM_HOST" -p "$UPSTREAM_PORT" -U "$UPSTREAM_USER" -d "$UPSTREAM_DB" -t -A -c \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE '$TABLE_PATTERN' ORDER BY tablename;")

if [ -z "$TABLES" ]; then
  echo "!!! 未找到匹配的表（pattern: $TABLE_PATTERN），退出。"
  exit 1
fi

echo ">>> 找到以下表："
echo "$TABLES" | while read t; do echo "    - $t"; done
TABLE_COUNT=$(echo "$TABLES" | wc -l)
echo ">>> 共 $TABLE_COUNT 张表"

# 构建 pg_dump --table 参数
TABLE_ARGS=""
while IFS= read -r tbl; do
  TABLE_ARGS="$TABLE_ARGS --table=public.${tbl}"
done <<< "$TABLES"

DUMP_FILE="/tmp/community_${COMMUNITY}_$(date +%Y%m%d_%H%M%S).sql"

echo ""
echo ">>> 正在 dump 上游数据（文件: $DUMP_FILE）..."
pg_dump \
  -h "$UPSTREAM_HOST" \
  -p "$UPSTREAM_PORT" \
  -U "$UPSTREAM_USER" \
  -d "$UPSTREAM_DB" \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists \
  $TABLE_ARGS \
  -f "$DUMP_FILE"

if [ $? -ne 0 ]; then
  echo "!!! pg_dump 失败，请检查上游连接配置"
  exit 1
fi

echo ">>> dump 完成，文件大小: $(du -sh $DUMP_FILE | cut -f1)"

echo ""
echo ">>> 正在导入到本地数据库..."
export PGPASSWORD="$LOCAL_PASS"
psql \
  -h "$LOCAL_HOST" \
  -p "$LOCAL_PORT" \
  -U "$LOCAL_USER" \
  -d "$LOCAL_DB" \
  -f "$DUMP_FILE"

if [ $? -ne 0 ]; then
  echo "!!! 导入失败"
  exit 1
fi

echo ""
echo ">>> 清理临时文件..."
rm -f "$DUMP_FILE"

echo ""
echo "✓ 同步完成！community=$COMMUNITY，共同步 $TABLE_COUNT 张表。"
