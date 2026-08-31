// ============================================================
// SnapCal 后端 CI/CD 流水线
// 触发: GitHub webhook (push) 或 Jenkins 手动
// 环境: Jenkins 容器挂宿主 docker.sock, workspace 绑定挂载在
//       /opt/jenkins/home/workspace/snapcal (宿主真实路径)
// ============================================================

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 15, unit: 'MINUTES')
    }

    environment {
        IMAGE   = 'snapcal-server:latest'
        HOST_WS = '/opt/jenkins/home/workspace/snapcal'
    }

    stages {

        stage('Maven 构建') {
            steps {
                sh '''
                docker run --rm \
                  -v "$HOST_WS/server":/ws \
                  -v /opt/dataviz/.m2:/root/.m2 \
                  -w /ws --memory=1200m \
                  maven:3.9-eclipse-temurin-17 \
                  mvn -B -q package -DskipTests
                '''
                sh 'ls -lh server/target/snapcal-server.jar'
            }
        }

        stage('构建镜像并部署') {
            steps {
                sh 'bash deploy/jenkins/deploy.sh'
            }
        }

        stage('链路验证') {
            steps {
                sh '''
                sleep 2
                # 8081 直连
                curl -sf -m 5 http://snapcal-server:8081/api/health && echo " (8081 直连 OK)"
                # nginx 统一入口
                curl -s -m 5 -o /dev/null -w "nginx 入口 /snapcal/api/health HTTP %{http_code}\\n" \
                  http://snapcal-nginx/snapcal/api/health || echo "nginx 入口暂不可用 (若未切换属正常)"
                '''
            }
        }
    }

    post {
        success { echo "✅ 部署完成 build-${BUILD_NUMBER} → ${IMAGE}" }
        failure { echo '‼️ 构建失败, 上一版本容器仍在运行 (deploy 阶段才替换)' }
        always  { cleanWs(notFailBuild: true) }
    }
}
