#!/usr/bin/env bash
# ==============================================================================
# 一键构成 Neo4j 查询子图:
#   1. 等待容器内 Bolt 服务就绪(自动识别当前是临时密码还是程序密码)
#   2. 执行项目自定义 Cypher 脚本 init-adjacency-data.cypher 导入三大场景数据
#   3. 将密码切换为 application.yml 中配置的 mZcl6QqjopWQDq/7
#      (密码含 '/',无法直接通过 NEO4J_AUTH 环境变量设置,故先临时密码再 ALTER)
#
#   用法: ./init-neo4j.sh
#   幂等: Cypher 脚本全部使用 MERGE / IF NOT EXISTS,重复执行安全;
#         ALTER 密码仅在仍是临时密码时执行一次。
# ==============================================================================
set -euo pipefail

CONTAINER=neo4j-adjacency-demo
TEMP_PASS='initial-pass-4demo'
FINAL_PASS='mZcl6QqjopWQDq/7'
CYPHER_FILE='/cypher-init/init-adjacency-data.cypher'

# 探测当前可用密码:输出 'final' / 'temp' / 不可用
# 注意优先尝试程序密码:若先用已失效的临时密码反复失败,会触发 Neo4j 账户锁定
probe_pass() {
    if docker exec "$CONTAINER" cypher-shell -u neo4j -p "$FINAL_PASS" \
        "RETURN 1 AS ok;" >/dev/null 2>&1; then
        echo final
    elif docker exec "$CONTAINER" cypher-shell -u neo4j -p "$TEMP_PASS" \
        "RETURN 1 AS ok;" >/dev/null 2>&1; then
        echo temp
    else
        echo none
    fi
}

echo "==> [1/3] 等待 Neo4j Bolt 就绪..."
STATE=none
for i in $(seq 1 30); do
    STATE="$(probe_pass)"
    if [ "$STATE" != "none" ]; then
        echo "    Neo4j 已就绪(当前认证状态: $STATE)"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "    超时:Neo4j 未在预期时间内就绪" >&2
        exit 1
    fi
    sleep 2
done

# 选择当前可用的密码执行导入(脚本幂等,重复执行安全)
CURRENT_PASS="$TEMP_PASS"
[ "$STATE" = "final" ] && CURRENT_PASS="$FINAL_PASS"

echo "==> [2/3] 执行自定义 Cypher 脚本导入子图数据 ($CYPHER_FILE)..."
docker exec "$CONTAINER" cypher-shell -u neo4j -p "$CURRENT_PASS" -f "$CYPHER_FILE"

echo "==> [3/3] 切换密码为 application.yml 配置的密码..."
if [ "$STATE" = "temp" ]; then
    docker exec "$CONTAINER" cypher-shell -u neo4j -p "$TEMP_PASS" \
        "ALTER CURRENT USER SET PASSWORD FROM '$TEMP_PASS' TO '$FINAL_PASS';"
    echo "    密码已切换"
else
    echo "    跳过(密码此前已切换)"
fi

echo "==> 验证数据..."
docker exec "$CONTAINER" cypher-shell -u neo4j -p "$FINAL_PASS" \
    "MATCH (n) RETURN count(n) AS nodes;"
docker exec "$CONTAINER" cypher-shell -u neo4j -p "$FINAL_PASS" \
    "MATCH ()-[r]->() RETURN count(r) AS relationships;"

echo "完成:Neo4j 查询子图已就绪,Bolt: bolt://localhost:7687 (neo4j / application.yml 密码)"
