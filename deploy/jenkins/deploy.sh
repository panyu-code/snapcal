#!/bin/bash
# ============================================================
# SnapCal 后端部署脚本 (Jenkins 流水线调用, 幂等)
# 用法: 在流水线 workspace 根目录执行  bash deploy/jenkins/deploy.sh
# 环境变量:
#   BUILD_NUMBER  Jenkins 构建号 (可选, 用于回滚 tag)
#   IMAGE         镜像 tag (默认 snapcal-server:latest)
# ============================================================
set -e

CONTAINER=snapcal-server
IMAGE=${IMAGE:-snapcal-server:latest}
LOG_FILE=/opt/snapcal/server/snapcal.log

echo "===== 部署 SnapCal 后端: $IMAGE ====="

# 1. 构建镜像 (workspace 是宿主真实路径, docker.sock 直读)
docker build -t "$IMAGE" -f server/Dockerfile.quick server/
if [ -n "$BUILD_NUMBER" ]; then
    docker tag "$IMAGE" "snapcal-server:build-${BUILD_NUMBER}"
fi

# 2. 平滑重建容器 (参数与 restart.sh 完全一致)
docker rm -f $CONTAINER >/dev/null 2>&1
sleep 1

docker run -d \
  --name $CONTAINER \
  --network dataviz_dataviz-net \
  -p 8081:8081 \
  -e MYSQL_HOST=dataviz-mysql \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=YuPan95270. \
  -e DEV_MODE=true \
  -e VISION_PROVIDER=glm \
  -e VISION_API_KEY=02a6f3f5298c42c58926134b989d8e3c.LnR5sGZSqJy9YP4w \
  -e VISION_MODEL=glm-4v-flash \
  --restart=always \
  "$IMAGE" >/dev/null

echo "容器状态: $(docker ps --filter name=$CONTAINER --format "{{.Status}}")"

# 3. 日志接管
echo "" >> "$LOG_FILE"
echo "========== $(date "+%F %T") CI 部署 (build-${BUILD_NUMBER:-manual}) $IMAGE ==========" >> "$LOG_FILE"
nohup docker logs -f $CONTAINER >> "$LOG_FILE" 2>&1 &

# 4. 健康检查 (最多等 40s, /api/health 无需鉴权)
ok=""
for i in $(seq 1 20); do
    code=$(curl -s -m 2 http://127.0.0.1:8081/api/health -o /dev/null -w "%{http_code}" || true)
    if [ "$code" = "200" ]; then ok=1; break; fi
    sleep 2
done
if [ -z "$ok" ]; then
    echo "‼️ 健康检查失败"
    docker logs --tail 50 $CONTAINER
    exit 1
fi
echo "✅ 健康检查通过 (HTTP 200)"
