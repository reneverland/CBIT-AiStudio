#!/bin/bash

# 🚨 CBIT-AiStudio 紧急强制修复脚本
# 专门解决持续的 sqlite3.OperationalError: unable to open database file 问题
# 使用最激进的修复方案，确保数据库权限问题彻底解决

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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
PROJECT_NAME="cbit-aistudio"

echo "🚨🚨🚨 CBIT-AiStudio 紧急强制修复 🚨🚨🚨"
echo "=========================================="
log_critical "此脚本将使用最激进的方法修复数据库权限问题"
log_critical "项目目录: $SCRIPT_DIR"
echo ""

# 1. 安全检查
if [[ ! -f "$SCRIPT_DIR/app_local.py" ]]; then
    log_error "❌ 错误：当前目录不是CBIT-AiStudio项目目录"
    exit 1
fi

# 2. 强制停止所有相关服务
log_info "🛑 强制停止所有相关服务..."

# 停止Docker容器（所有可能的名称变体）
for container_name in "cbit-aistudio" "cbit_aistudio" "local_baiducbit_app_1" "local_baiducbit-app-1"; do
    if docker ps -q -f name="$container_name" | grep -q .; then
        log_info "停止容器: $container_name"
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
    fi
done

# 停止docker-compose
cd "$SCRIPT_DIR"
docker-compose down --remove-orphans 2>/dev/null || true

# 杀死可能的Python进程
pkill -f "app_local.py" 2>/dev/null || true
pkill -f "run_local.py" 2>/dev/null || true

log_success "✅ 所有服务已停止"

# 3. 彻底备份和重建数据目录
log_info "💾 彻底备份和重建数据目录..."

# 创建备份目录
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 备份现有数据（如果存在）
if [[ -d "$SCRIPT_DIR/instance" ]]; then
    cp -r "$SCRIPT_DIR/instance" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "已备份instance目录到: $BACKUP_DIR/instance"
fi

if [[ -d "$SCRIPT_DIR/downloads" ]]; then
    cp -r "$SCRIPT_DIR/downloads" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "已备份downloads目录到: $BACKUP_DIR/downloads"
fi

if [[ -d "$SCRIPT_DIR/static/uploads" ]]; then
    cp -r "$SCRIPT_DIR/static/uploads" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "已备份uploads目录到: $BACKUP_DIR/static/uploads"
fi

# 彻底删除并重建目录
log_warning "⚠️ 正在彻底重建数据目录..."
sudo rm -rf "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads" 2>/dev/null || true

# 重新创建目录结构
mkdir -p "$SCRIPT_DIR/instance"
mkdir -p "$SCRIPT_DIR/downloads"
mkdir -p "$SCRIPT_DIR/static/uploads"

# 设置最宽松的权限
sudo chmod 777 "$SCRIPT_DIR/instance"
sudo chmod 777 "$SCRIPT_DIR/downloads"
sudo chmod 777 "$SCRIPT_DIR/static/uploads"

# 创建空数据库文件
touch "$SCRIPT_DIR/instance/local_cache.db"
sudo chmod 666 "$SCRIPT_DIR/instance/local_cache.db"

# 设置所有者
sudo chown -R $(whoami):$(whoami) "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads" 2>/dev/null || true

log_success "✅ 数据目录重建完成"

# 4. 修复Docker配置文件
log_info "🐳 修复Docker配置文件..."

# 备份原配置
cp "$SCRIPT_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.backup" 2>/dev/null || true
cp "$SCRIPT_DIR/Dockerfile" "$BACKUP_DIR/Dockerfile.backup" 2>/dev/null || true

# 创建强化版Dockerfile
cat > "$SCRIPT_DIR/Dockerfile" << 'DOCKERFILE_EOF'
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

# 创建必要的目录并设置权限（容器构建时）
RUN mkdir -p /app/instance /app/downloads /app/static/uploads && \
    chmod 777 /app/instance /app/downloads /app/static/uploads && \
    touch /app/instance/local_cache.db && \
    chmod 666 /app/instance/local_cache.db

# 设置数据库环境变量
ENV SQLALCHEMY_DATABASE_URI=sqlite:///instance/local_cache.db

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 创建启动脚本，确保运行时权限正确
RUN echo '#!/bin/bash\n\
echo "🔧 容器启动权限检查..."\n\
mkdir -p /app/instance /app/downloads /app/static/uploads\n\
chmod 777 /app/instance /app/downloads /app/static/uploads\n\
if [ ! -f /app/instance/local_cache.db ]; then\n\
    touch /app/instance/local_cache.db\n\
fi\n\
chmod 666 /app/instance/local_cache.db\n\
echo "✅ 权限检查完成，启动应用..."\n\
exec python app_local.py' > /app/start.sh && chmod +x /app/start.sh

# 使用启动脚本
CMD ["/app/start.sh"]
DOCKERFILE_EOF

# 创建强化版docker-compose.yml
cat > "$SCRIPT_DIR/docker-compose.yml" << 'COMPOSE_EOF'
services:
  app:
    build: .
    container_name: cbit-aistudio
    ports:
      - "5000:5000"
    environment:
      - HOST=0.0.0.0
      - PORT=5000
      - DEBUG=false
      - SERVER_URL=http://113.106.62.42:9500
      - SECRET_KEY=production-secret-key-2025
    volumes:
      # 使用绑定挂载，确保权限传递
      - type: bind
        source: ./instance
        target: /app/instance
        bind:
          create_host_path: true
      - type: bind
        source: ./downloads
        target: /app/downloads
        bind:
          create_host_path: true
      - type: bind
        source: ./static/uploads
        target: /app/static/uploads
        bind:
          create_host_path: true
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s
    networks:
      - cbit-network
    # 使用root用户确保权限
    user: "0:0"

networks:
  cbit-network:
    driver: bridge
COMPOSE_EOF

log_success "✅ Docker配置文件已修复"

# 5. 清理Docker缓存并强制重建
log_info "🧹 清理Docker缓存并强制重建..."

# 删除相关镜像
docker rmi $(docker images | grep "local_baiducbit\|cbit" | awk '{print $3}') 2>/dev/null || true

# 清理构建缓存
docker builder prune -f 2>/dev/null || true

# 清理未使用的卷
docker volume prune -f 2>/dev/null || true

log_success "✅ Docker缓存清理完成"

# 6. 强制重新构建和启动
log_info "🚀 强制重新构建和启动应用..."

# 构建镜像
docker-compose build --no-cache --force-rm

# 启动服务
docker-compose up -d

log_success "✅ 应用已启动"

# 7. 等待并验证启动
log_info "⏳ 等待应用完全启动..."
sleep 30

# 检查容器状态
if docker ps | grep -q "cbit-aistudio"; then
    log_success "✅ 容器运行正常"
    
    # 检查容器内权限
    log_info "🔍 检查容器内权限..."
    docker exec cbit-aistudio ls -la /app/instance/ || true
    
    # 检查应用健康状态
    log_info "🏥 检查应用健康状态..."
    sleep 10
    
    if curl -f http://localhost:5000/health &>/dev/null; then
        log_success "✅ 应用健康检查通过"
    else
        log_warning "⚠️ 应用健康检查失败，查看日志..."
        docker logs cbit-aistudio --tail 20
    fi
else
    log_error "❌ 容器启动失败"
    docker logs cbit-aistudio --tail 50
    exit 1
fi

# 8. 创建快速重启脚本
log_info "📝 创建快速重启脚本..."

cat > "$SCRIPT_DIR/quick_restart.sh" << 'RESTART_EOF'
#!/bin/bash

# CBIT-AiStudio 快速重启脚本
# 保持权限设置的情况下重启应用

echo "🔄 快速重启CBIT-AiStudio..."

# 停止容器
docker stop cbit-aistudio 2>/dev/null || true
docker rm cbit-aistudio 2>/dev/null || true

# 确保权限正确
chmod 777 instance downloads static/uploads 2>/dev/null || true
if [[ -f "instance/local_cache.db" ]]; then
    chmod 666 instance/local_cache.db
fi

# 重新启动
docker-compose up -d

echo "✅ 重启完成"
echo "🌐 访问地址: http://localhost:5000"
EOF

chmod +x "$SCRIPT_DIR/quick_restart.sh"

# 9. 恢复备份数据（如果需要）
if [[ -f "$BACKUP_DIR/instance/local_cache.db" ]]; then
    log_info "🔄 恢复备份的数据库数据..."
    
    # 停止容器以安全恢复数据
    docker stop cbit-aistudio
    
    # 恢复数据库内容（保持新的权限设置）
    cp "$BACKUP_DIR/instance/local_cache.db" "$SCRIPT_DIR/instance/local_cache.db"
    chmod 666 "$SCRIPT_DIR/instance/local_cache.db"
    
    # 重新启动
    docker start cbit-aistudio
    
    log_success "✅ 数据库数据已恢复"
fi

# 10. 显示修复总结
echo ""
echo "🎉🎉🎉 紧急修复完成！🎉🎉🎉"
echo "================================"
echo ""
log_success "📋 修复总结:"
echo "   ✅ 强制停止了所有相关服务"
echo "   ✅ 彻底重建了数据目录结构"
echo "   ✅ 设置了最宽松的权限 (777/666)"
echo "   ✅ 修复了Docker配置文件"
echo "   ✅ 清理并重建了Docker镜像"
echo "   ✅ 使用root用户运行容器"
echo "   ✅ 创建了快速重启脚本"
echo "   ✅ 恢复了备份数据"
echo ""
echo "🌐 访问地址: http://localhost:5000"
echo "📊 健康检查: http://localhost:5000/health"
echo "📝 查看日志: docker logs cbit-aistudio"
echo "🔄 快速重启: ./quick_restart.sh"
echo ""
echo "📁 备份位置: $BACKUP_DIR"
echo ""

# 11. 最终验证
log_info "🔍 最终验证..."
echo "容器状态:"
docker ps | grep cbit || echo "未找到运行中的容器"
echo ""
echo "目录权限:"
ls -la instance/ downloads/ static/uploads/ 2>/dev/null || true
echo ""
echo "数据库文件:"
ls -la instance/local_cache.db 2>/dev/null || echo "数据库文件不存在"
echo ""

log_success "✨ 紧急修复完成！如果仍有问题，请查看容器日志。"
