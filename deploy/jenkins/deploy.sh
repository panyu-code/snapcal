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

echo "===== 部署 SnapCal 后端: $IMAGE ====="

# 1. 构建镜像 (workspace 是宿主真实路径, docker.sock 直读)
docker build -t "$IMAGE" -f server/Dockerfile.quick server/
if [ -n "$BUILD_NUMBER" ]; then
    docker tag "$IMAGE" "snapcal-server:build-${BUILD_NUMBER}"
fi

# 2. 平滑重建容器 (参数与 restart.sh 完全一致)
docker rm -f $CONTAINER >/dev/null 2>&1
sleep 1

ENV_FILE=/opt/snapcal/server/.env
if [ ! -f "$ENV_FILE" ]; then
  echo "‼️ 缺少服务器环境文件: $ENV_FILE"
  exit 1
fi

docker run -d \
  --name $CONTAINER \
  --network dataviz_dataviz-net \
  -p 8081:8081 \
  --env-file "$ENV_FILE" \
  --restart=always \
  "$IMAGE" >/dev/null

echo "容器状态: $(docker ps --filter name=$CONTAINER --format "{{.Status}}")"

# 3. 日志: 由 docker 自身管理, 查看用 docker logs snapcal-server
#    (脚本运行在 Jenkins 容器内, 不能写宿主路径; 历史日志见流水线控制台)
echo "CI 部署 build-${BUILD_NUMBER:-manual} $IMAGE @ $(date "+%F %T")"

# 4. 健康检查 (最多等 40s, /api/health 无需鉴权)
# 兼容两种运行环境: 宿主机直跑(127.0.0.1) / Jenkins 容器内(容器名走 docker 网络)
ok=""
for i in $(seq 1 20); do
    code=$(curl -s -m 2 http://127.0.0.1:8081/api/health -o /dev/null -w "%{http_code}" || true)
    [ "$code" = "200" ] || code=$(curl -s -m 2 http://snapcal-server:8081/api/health -o /dev/null -w "%{http_code}" || true)
    if [ "$code" = "200" ]; then ok=1; break; fi
    sleep 2
done
if [ -z "$ok" ]; then
    echo "‼️ 健康检查失败"
    docker logs --tail 50 $CONTAINER
    exit 1
fi
echo "✅ 健康检查通过 (HTTP 200)"
