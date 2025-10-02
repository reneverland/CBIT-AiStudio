#!/bin/bash

# 🚨 宝塔面板专用 - CBIT-AiStudio 数据库紧急修复脚本
# 专门针对宝塔环境的 sqlite3.OperationalError: unable to open database file 问题
# 安全设计：只影响CBIT-AiStudio项目，不影响其他宝塔容器

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
    echo -e "${BLUE}[宝塔修复]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

log_critical() {
    echo -e "${PURPLE}[关键]${NC} $1"
}

# 检测宝塔环境
detect_baota_env() {
    if [[ -d "/www/server/panel" ]] || [[ -f "/etc/init.d/bt" ]]; then
        return 0
    else
        return 1
    fi
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="cbit-aistudio"

echo "🏢🚨 宝塔面板 - CBIT-AiStudio 数据库紧急修复 🚨🏢"
echo "=================================================="
log_critical "专门针对宝塔环境的数据库权限修复"
log_critical "项目目录: $SCRIPT_DIR"

# 检测环境
if detect_baota_env; then
    log_success "✅ 检测到宝塔面板环境"
else
    log_warning "⚠️ 未检测到宝塔面板，但继续执行修复"
fi

echo ""

# 1. 安全检查
if [[ ! -f "$SCRIPT_DIR/app_local.py" ]]; then
    log_error "❌ 错误：当前目录不是CBIT-AiStudio项目目录"
    log_error "请确保在项目根目录运行此脚本"
    log_error "宝塔项目路径通常为: /www/wwwroot/CBIT-AiStudio"
    exit 1
fi

# 2. 检查Docker环境
if ! command -v docker &> /dev/null; then
    log_error "❌ Docker未安装"
    log_error "请在宝塔面板 -> 软件商店 -> 搜索'Docker' -> 安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    log_error "❌ Docker Compose未安装"
    log_error "请安装Docker Compose或使用 'docker compose' 命令"
fi

# 3. 宝塔环境特殊处理 - 安全停止容器
log_info "🛑 安全停止CBIT-AiStudio容器（不影响其他宝塔容器）..."

cd "$SCRIPT_DIR"

# 只停止CBIT-AiStudio相关的容器
CONTAINERS_TO_STOP=("cbit-aistudio" "cbit_aistudio" "local_baiducbit_app_1" "local_baiducbit-app-1")

for container_name in "${CONTAINERS_TO_STOP[@]}"; do
    if docker ps -q -f name="^${container_name}$" | grep -q .; then
        log_info "停止容器: $container_name"
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        log_success "✅ 已停止容器: $container_name"
    fi
done

# 停止docker-compose（只影响当前项目）
docker-compose down --remove-orphans 2>/dev/null || true

log_success "✅ CBIT-AiStudio容器已安全停止，其他宝塔容器未受影响"

# 4. 宝塔环境权限修复
log_info "🔧 宝塔环境权限修复..."

# 创建备份
BACKUP_DIR="$SCRIPT_DIR/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 备份现有数据
if [[ -d "$SCRIPT_DIR/instance" ]]; then
    cp -r "$SCRIPT_DIR/instance" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "已备份instance目录"
fi

# 确保目录存在
mkdir -p "$SCRIPT_DIR/instance"
mkdir -p "$SCRIPT_DIR/downloads"
mkdir -p "$SCRIPT_DIR/static/uploads"

# 宝塔环境特殊权限设置
# 设置目录权限（宝塔环境通常需要www用户）
if id "www" &>/dev/null; then
    # 宝塔环境有www用户
    log_info "检测到www用户，设置宝塔兼容权限..."
    sudo chown -R www:www "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads" 2>/dev/null || true
    sudo chmod 755 "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads"
    
    # 为Docker容器访问添加额外权限
    sudo chmod g+w "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads"
    sudo chmod o+w "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads"
else
    # 非宝塔环境或没有www用户
    log_info "未检测到www用户，使用通用权限设置..."
    sudo chmod 777 "$SCRIPT_DIR/instance" "$SCRIPT_DIR/downloads" "$SCRIPT_DIR/static/uploads"
fi

# 创建数据库文件并设置权限
if [[ ! -f "$SCRIPT_DIR/instance/local_cache.db" ]]; then
    touch "$SCRIPT_DIR/instance/local_cache.db"
fi

sudo chmod 666 "$SCRIPT_DIR/instance/local_cache.db"

# 如果有www用户，也设置所有者
if id "www" &>/dev/null; then
    sudo chown www:www "$SCRIPT_DIR/instance/local_cache.db" 2>/dev/null || true
fi

log_success "✅ 宝塔环境权限设置完成"

# 5. 创建宝塔优化的Docker配置
log_info "🐳 创建宝塔优化的Docker配置..."

# 备份原配置
cp "$SCRIPT_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.backup" 2>/dev/null || true

# 创建宝塔优化版docker-compose.yml
cat > "$SCRIPT_DIR/docker-compose.yml" << 'BAOTA_COMPOSE_EOF'
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
      # 宝塔环境优化的卷挂载
      - ./instance:/app/instance:rw
      - ./downloads:/app/downloads:rw
      - ./static/uploads:/app/static/uploads:rw
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s
    networks:
      - cbit-network
    # 宝塔环境用户设置
    user: "0:0"
    # 添加必要的capabilities
    cap_add:
      - DAC_OVERRIDE
    # 宝塔环境安全设置
    security_opt:
      - no-new-privileges:true

networks:
  cbit-network:
    driver: bridge
    name: cbit-network
BAOTA_COMPOSE_EOF

# 创建宝塔优化的Dockerfile
cat > "$SCRIPT_DIR/Dockerfile" << 'BAOTA_DOCKERFILE_EOF'
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

# 创建必要的目录并设置权限
RUN mkdir -p /app/instance /app/downloads /app/static/uploads && \
    chmod 777 /app/instance /app/downloads /app/static/uploads

# 设置数据库环境变量
ENV SQLALCHEMY_DATABASE_URI=sqlite:///instance/local_cache.db

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 创建宝塔环境启动脚本
RUN echo '#!/bin/bash\n\
echo "🏢 宝塔环境启动检查..."\n\
mkdir -p /app/instance /app/downloads /app/static/uploads\n\
chmod 777 /app/instance /app/downloads /app/static/uploads\n\
if [ ! -f /app/instance/local_cache.db ]; then\n\
    touch /app/instance/local_cache.db\n\
fi\n\
chmod 666 /app/instance/local_cache.db\n\
echo "✅ 宝塔环境权限检查完成"\n\
echo "🚀 启动CBIT-AiStudio应用..."\n\
exec python app_local.py' > /app/baota_start.sh && chmod +x /app/baota_start.sh

# 使用宝塔启动脚本
CMD ["/app/baota_start.sh"]
BAOTA_DOCKERFILE_EOF

log_success "✅ 宝塔优化配置创建完成"

# 6. 清理并重建（宝塔环境安全）
log_info "🧹 清理Docker缓存并重建..."

# 只清理CBIT相关的镜像，不影响其他宝塔容器
docker images | grep -E "(cbit|local_baiducbit)" | awk '{print $3}' | xargs -r docker rmi 2>/dev/null || true

# 构建新镜像
log_info "🔨 构建新的Docker镜像..."
docker-compose build --no-cache

# 7. 启动服务
log_info "🚀 启动CBIT-AiStudio服务..."
docker-compose up -d

# 8. 等待并验证
log_info "⏳ 等待服务启动..."
sleep 30

# 检查容器状态
if docker ps | grep -q "cbit-aistudio"; then
    log_success "✅ 容器运行正常"
    
    # 检查应用健康
    log_info "🏥 检查应用健康状态..."
    sleep 15
    
    # 尝试多次健康检查
    for i in {1..5}; do
        if curl -f http://localhost:5000/health &>/dev/null; then
            log_success "✅ 应用健康检查通过（第${i}次尝试）"
            break
        else
            log_warning "⚠️ 健康检查失败，第${i}次尝试..."
            sleep 10
        fi
    done
    
    # 显示容器日志（最后20行）
    log_info "📋 容器日志（最后20行）："
    docker logs cbit-aistudio --tail 20
    
else
    log_error "❌ 容器启动失败"
    log_error "查看完整日志："
    docker logs cbit-aistudio
    exit 1
fi

# 9. 创建宝塔管理脚本
log_info "📝 创建宝塔管理脚本..."

cat > "$SCRIPT_DIR/baota_manage.sh" << 'BAOTA_MANAGE_EOF'
#!/bin/bash

# 宝塔面板 - CBIT-AiStudio 管理脚本

case "$1" in
    start)
        echo "🚀 启动CBIT-AiStudio..."
        docker-compose up -d
        ;;
    stop)
        echo "🛑 停止CBIT-AiStudio..."
        docker-compose down
        ;;
    restart)
        echo "🔄 重启CBIT-AiStudio..."
        docker-compose restart
        ;;
    logs)
        echo "📋 查看日志..."
        docker logs cbit-aistudio -f
        ;;
    status)
        echo "📊 服务状态..."
        docker ps | grep cbit || echo "服务未运行"
        ;;
    health)
        echo "🏥 健康检查..."
        curl -f http://localhost:5000/health && echo "✅ 健康" || echo "❌ 不健康"
        ;;
    fix-permissions)
        echo "🔧 修复权限..."
        chmod 777 instance downloads static/uploads
        chmod 666 instance/local_cache.db 2>/dev/null || true
        echo "✅ 权限修复完成"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|logs|status|health|fix-permissions}"
        exit 1
        ;;
esac
BAOTA_MANAGE_EOF

chmod +x "$SCRIPT_DIR/baota_manage.sh"

# 10. 宝塔面板集成提示
echo ""
echo "🏢🎉 宝塔环境修复完成！🎉🏢"
echo "================================"
echo ""
log_success "📋 修复总结:"
echo "   ✅ 安全停止了CBIT-AiStudio容器（未影响其他宝塔容器）"
echo "   ✅ 设置了宝塔兼容的权限配置"
echo "   ✅ 创建了宝塔优化的Docker配置"
echo "   ✅ 重建了Docker镜像和容器"
echo "   ✅ 创建了宝塔管理脚本"
echo ""
echo "🌐 访问地址: http://服务器IP:5000"
echo "📊 健康检查: http://服务器IP:5000/health"
echo ""
echo "🛠️ 宝塔管理命令:"
echo "   启动服务: ./baota_manage.sh start"
echo "   停止服务: ./baota_manage.sh stop"
echo "   重启服务: ./baota_manage.sh restart"
echo "   查看日志: ./baota_manage.sh logs"
echo "   检查状态: ./baota_manage.sh status"
echo "   健康检查: ./baota_manage.sh health"
echo "   修复权限: ./baota_manage.sh fix-permissions"
echo ""
echo "📁 备份位置: $BACKUP_DIR"
echo ""

# 11. 宝塔面板配置建议
log_info "🏢 宝塔面板配置建议:"
echo ""
echo "1. 防火墙设置:"
echo "   宝塔面板 -> 安全 -> 防火墙 -> 添加端口规则"
echo "   端口: 5000, 类型: TCP, 说明: CBIT-AiStudio"
echo ""
echo "2. 反向代理设置（可选）:"
echo "   宝塔面板 -> 网站 -> 添加站点 -> 配置反向代理"
echo "   目标URL: http://127.0.0.1:5000"
echo ""
echo "3. 定时任务设置（可选）:"
echo "   宝塔面板 -> 计划任务 -> Shell脚本"
echo "   脚本内容: cd $SCRIPT_DIR && ./baota_manage.sh health"
echo ""

log_success "✨ 宝塔环境修复完成！应用应该可以正常运行了。"
log_info "如果仍有问题，请运行: ./baota_manage.sh logs 查看详细日志"
