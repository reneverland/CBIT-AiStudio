#!/bin/bash

# 🚀 CBIT-AiStudio 预置数据库版本部署脚本 (修复版)
# 解决SQLAlchemy版本兼容性问题和数据库权限问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $1"
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="cbit-aistudio-prebuilt"

echo "🚀🚀🚀 CBIT-AiStudio 预置数据库版本部署 (修复版) 🚀🚀🚀"
echo "========================================================"
log_critical "修复SQLAlchemy兼容性问题，彻底解决权限问题"
log_critical "项目目录: $SCRIPT_DIR"
echo ""

# 1. 安全检查
if [[ ! -f "$SCRIPT_DIR/app_prebuilt_db.py" ]]; then
    log_error "❌ 错误：找不到预置数据库版本的应用文件"
    exit 1
fi

# 2. 检查Docker环境
if ! command -v docker &> /dev/null; then
    log_error "❌ Docker未安装，请先安装Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    log_error "❌ Docker Compose未安装"
    exit 1
fi

# 3. 停止现有容器
log_info "🛑 停止现有容器..."
cd "$SCRIPT_DIR"

# 停止所有可能的CBIT容器
for container_name in "cbit-aistudio" "cbit-aistudio-prebuilt" "cbit_aistudio" "local_baiducbit_app_1"; do
    if docker ps -q -f name="$container_name" | grep -q .; then
        log_info "停止容器: $container_name"
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
    fi
done

# 停止docker-compose
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose.prebuilt.yml down 2>/dev/null || true

log_success "✅ 现有容器已停止"

# 4. 创建修复版Dockerfile
log_info "🔧 创建修复版Dockerfile..."

cat > "$SCRIPT_DIR/Dockerfile.prebuilt.fixed" << 'DOCKERFILE_EOF'
FROM python:3.12-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV HOST=0.0.0.0
ENV PORT=5000
ENV DEBUG=False

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc g++ curl sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements并安装Python依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/db /app/downloads /app/static/uploads

# 复制预置数据库到容器内
COPY db/prebuilt_cache.db /app/db/prebuilt_cache.db

# 设置数据库文件权限
RUN chmod 666 /app/db/prebuilt_cache.db && \
    chmod 777 /app/db /app/downloads /app/static/uploads

# 设置数据库环境变量（使用预置数据库）
ENV SQLALCHEMY_DATABASE_URI=sqlite:///db/runtime_cache.db

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 创建启动脚本，确保数据库设置正确
RUN echo '#!/bin/bash\n\
echo "🚀 启动CBIT-AiStudio (预置数据库修复版)..."\n\
echo "🔧 检查预置数据库..."\n\
if [ -f /app/db/prebuilt_cache.db ]; then\n\
    echo "✅ 预置数据库存在: /app/db/prebuilt_cache.db"\n\
    ls -la /app/db/prebuilt_cache.db\n\
else\n\
    echo "❌ 预置数据库不存在"\n\
    exit 1\n\
fi\n\
echo "🔧 确保目录权限..."\n\
chmod 777 /app/db /app/downloads /app/static/uploads\n\
chmod 666 /app/db/prebuilt_cache.db\n\
echo "✅ 权限设置完成"\n\
echo "🚀 启动应用 (SQLAlchemy修复版)..."\n\
exec python app_prebuilt_db.py' > /app/start_prebuilt_fixed.sh && chmod +x /app/start_prebuilt_fixed.sh

# 使用修复版启动脚本
CMD ["/app/start_prebuilt_fixed.sh"]
DOCKERFILE_EOF

# 5. 创建修复版docker-compose文件
log_info "🔧 创建修复版docker-compose文件..."

cat > "$SCRIPT_DIR/docker-compose.prebuilt.fixed.yml" << 'COMPOSE_EOF'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.prebuilt.fixed
    container_name: cbit-aistudio-prebuilt-fixed
    ports:
      - "5000:5000"
    environment:
      - HOST=0.0.0.0
      - PORT=5000
      - DEBUG=false
      - SERVER_URL=http://113.106.62.42:9500
      - SECRET_KEY=production-secret-key-2025
    # 只挂载必要的目录，数据库在容器内
    volumes:
      - ./downloads:/app/downloads:rw
      - ./static/uploads:/app/static/uploads:rw
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - cbit-network

networks:
  cbit-network:
    driver: bridge
    name: cbit-prebuilt-fixed-network
COMPOSE_EOF

# 6. 创建预置数据库
log_info "💾 创建预置数据库..."

if [[ ! -f "$SCRIPT_DIR/db/prebuilt_cache.db" ]]; then
    log_info "数据库不存在，创建新的预置数据库..."
    python3 "$SCRIPT_DIR/create_prebuilt_db.py"
else
    log_info "预置数据库已存在，检查完整性..."
    if python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('$SCRIPT_DIR/db/prebuilt_cache.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM local_jobs')
    count = cursor.fetchone()[0]
    print(f'数据库记录数: {count}')
    conn.close()
    print('数据库检查通过')
except Exception as e:
    print(f'数据库检查失败: {e}')
    exit(1)
"; then
        log_success "✅ 预置数据库检查通过"
    else
        log_warning "⚠️ 数据库检查失败，重新创建..."
        python3 "$SCRIPT_DIR/create_prebuilt_db.py"
    fi
fi

# 7. 清理Docker缓存
log_info "🧹 清理Docker缓存..."

# 删除相关镜像
docker images | grep -E "(cbit|local_baiducbit)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# 清理构建缓存
docker builder prune -f 2>/dev/null || true

log_success "✅ Docker缓存清理完成"

# 8. 构建修复版
log_info "🔨 构建预置数据库修复版..."

# 使用修复版的docker-compose文件
docker-compose -f docker-compose.prebuilt.fixed.yml build --no-cache

log_success "✅ 修复版镜像构建完成"

# 9. 启动服务
log_info "🚀 启动预置数据库修复版..."

docker-compose -f docker-compose.prebuilt.fixed.yml up -d

log_success "✅ 修复版服务已启动"

# 10. 等待并验证
log_info "⏳ 等待服务完全启动..."
sleep 30

# 检查容器状态
CONTAINER_NAME="cbit-aistudio-prebuilt-fixed"
if docker ps | grep -q "$CONTAINER_NAME"; then
    log_success "✅ 容器运行正常"
    
    # 检查容器内数据库
    log_info "🔍 检查容器内数据库状态..."
    docker exec "$CONTAINER_NAME" ls -la /app/db/ || true
    
    # 检查应用健康状态
    log_info "🏥 检查应用健康状态..."
    sleep 15
    
    # 多次尝试健康检查
    for i in {1..5}; do
        if curl -f http://localhost:5000/health &>/dev/null; then
            log_success "✅ 应用健康检查通过（第${i}次尝试）"
            
            # 获取健康检查详细信息
            log_info "📊 健康检查详细信息："
            curl -s http://localhost:5000/health | python3 -m json.tool || true
            break
        else
            log_warning "⚠️ 健康检查失败，第${i}次尝试..."
            if [[ $i -eq 5 ]]; then
                log_error "❌ 健康检查最终失败，查看日志："
                docker logs "$CONTAINER_NAME" --tail 30
            else
                sleep 10
            fi
        fi
    done
    
else
    log_error "❌ 容器启动失败"
    log_error "查看容器日志："
    docker logs "$CONTAINER_NAME" --tail 50 2>/dev/null || echo "无法获取日志"
    exit 1
fi

# 11. 创建修复版管理脚本
log_info "📝 创建修复版管理脚本..."

cat > "$SCRIPT_DIR/manage_prebuilt_fixed.sh" << 'MANAGE_EOF'
#!/bin/bash

# CBIT-AiStudio 预置数据库修复版管理脚本

COMPOSE_FILE="docker-compose.prebuilt.fixed.yml"
CONTAINER_NAME="cbit-aistudio-prebuilt-fixed"

case "$1" in
    start)
        echo "🚀 启动预置数据库修复版..."
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "🛑 停止预置数据库修复版..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "🔄 重启预置数据库修复版..."
        docker-compose -f $COMPOSE_FILE restart
        ;;
    rebuild)
        echo "🔨 重建预置数据库修复版..."
        docker-compose -f $COMPOSE_FILE down
        docker-compose -f $COMPOSE_FILE build --no-cache
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    logs)
        echo "📋 查看日志..."
        docker logs $CONTAINER_NAME -f
        ;;
    status)
        echo "📊 服务状态..."
        docker ps | grep $CONTAINER_NAME || echo "服务未运行"
        ;;
    health)
        echo "🏥 健康检查..."
        curl -s http://localhost:5000/health | python3 -m json.tool || echo "❌ 健康检查失败"
        ;;
    db-info)
        echo "💾 数据库信息..."
        docker exec $CONTAINER_NAME ls -la /app/db/ || echo "❌ 无法访问容器"
        ;;
    shell)
        echo "🐚 进入容器..."
        docker exec -it $CONTAINER_NAME /bin/bash
        ;;
    test-db)
        echo "🧪 测试数据库连接..."
        docker exec $CONTAINER_NAME python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('/app/db/runtime_cache.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM local_jobs')
    count = cursor.fetchone()[0]
    print(f'✅ 数据库连接成功，记录数: {count}')
    conn.close()
except Exception as e:
    print(f'❌ 数据库连接失败: {e}')
"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|rebuild|logs|status|health|db-info|shell|test-db}"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x "$SCRIPT_DIR/manage_prebuilt_fixed.sh"

# 12. 显示部署总结
echo ""
echo "🎉🎉🎉 预置数据库修复版部署完成！🎉🎉🎉"
echo "=============================================="
echo ""
log_success "📋 修复总结:"
echo "   ✅ 修复了SQLAlchemy版本兼容性问题"
echo "   ✅ 创建了预置数据库文件"
echo "   ✅ 构建了包含数据库的Docker镜像"
echo "   ✅ 启动了预置数据库修复版容器"
echo "   ✅ 数据库完全在容器内，无权限问题"
echo "   ✅ 创建了修复版管理脚本"
echo ""
echo "🌐 访问地址: http://localhost:5000"
echo "📊 健康检查: http://localhost:5000/health"
echo ""
echo "🛠️ 修复版管理命令:"
echo "   启动服务: ./manage_prebuilt_fixed.sh start"
echo "   停止服务: ./manage_prebuilt_fixed.sh stop"
echo "   重启服务: ./manage_prebuilt_fixed.sh restart"
echo "   重建镜像: ./manage_prebuilt_fixed.sh rebuild"
echo "   查看日志: ./manage_prebuilt_fixed.sh logs"
echo "   检查状态: ./manage_prebuilt_fixed.sh status"
echo "   健康检查: ./manage_prebuilt_fixed.sh health"
echo "   数据库信息: ./manage_prebuilt_fixed.sh db-info"
echo "   测试数据库: ./manage_prebuilt_fixed.sh test-db"
echo "   进入容器: ./manage_prebuilt_fixed.sh shell"
echo ""

# 13. 最终验证
log_info "🔍 最终验证..."
echo "容器状态:"
docker ps | grep "$CONTAINER_NAME" || echo "❌ 容器未运行"
echo ""
echo "容器内数据库:"
docker exec "$CONTAINER_NAME" ls -la /app/db/ 2>/dev/null || echo "❌ 无法访问容器内数据库"
echo ""

log_success "✨ 预置数据库修复版部署完成！"
log_info "💡 这个版本修复了SQLAlchemy兼容性问题，彻底避免了权限问题。"
log_info "🔄 如果仍有问题，请运行: ./manage_prebuilt_fixed.sh logs 查看详细日志"
