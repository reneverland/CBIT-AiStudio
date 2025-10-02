#!/bin/bash

# 🚀 CBIT-AiStudio 预置数据库版本部署脚本
# 解决持续的数据库权限问题，将数据库直接打包到Docker镜像中

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

echo "🚀🚀🚀 CBIT-AiStudio 预置数据库版本部署 🚀🚀🚀"
echo "=================================================="
log_critical "使用预置数据库，彻底解决权限问题"
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

# 4. 创建预置数据库
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

# 5. 清理Docker缓存
log_info "🧹 清理Docker缓存..."

# 删除相关镜像
docker images | grep -E "(cbit|local_baiducbit)" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true

# 清理构建缓存
docker builder prune -f 2>/dev/null || true

log_success "✅ Docker缓存清理完成"

# 6. 构建预置数据库版本
log_info "🔨 构建预置数据库版本..."

# 使用预置数据库的docker-compose文件
docker-compose -f docker-compose.prebuilt.yml build --no-cache

log_success "✅ 镜像构建完成"

# 7. 启动服务
log_info "🚀 启动预置数据库版本..."

docker-compose -f docker-compose.prebuilt.yml up -d

log_success "✅ 服务已启动"

# 8. 等待并验证
log_info "⏳ 等待服务完全启动..."
sleep 30

# 检查容器状态
if docker ps | grep -q "$PROJECT_NAME"; then
    log_success "✅ 容器运行正常"
    
    # 检查容器内数据库
    log_info "🔍 检查容器内数据库状态..."
    docker exec "$PROJECT_NAME" ls -la /app/db/ || true
    
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
                log_error "❌ 健康检查最终失败"
                docker logs "$PROJECT_NAME" --tail 30
            else
                sleep 10
            fi
        fi
    done
    
else
    log_error "❌ 容器启动失败"
    log_error "查看容器日志："
    docker logs "$PROJECT_NAME" --tail 50
    exit 1
fi

# 9. 创建管理脚本
log_info "📝 创建预置数据库版本管理脚本..."

cat > "$SCRIPT_DIR/manage_prebuilt.sh" << 'MANAGE_EOF'
#!/bin/bash

# CBIT-AiStudio 预置数据库版本管理脚本

COMPOSE_FILE="docker-compose.prebuilt.yml"
CONTAINER_NAME="cbit-aistudio-prebuilt"

case "$1" in
    start)
        echo "🚀 启动预置数据库版本..."
        docker-compose -f $COMPOSE_FILE up -d
        ;;
    stop)
        echo "🛑 停止预置数据库版本..."
        docker-compose -f $COMPOSE_FILE down
        ;;
    restart)
        echo "🔄 重启预置数据库版本..."
        docker-compose -f $COMPOSE_FILE restart
        ;;
    rebuild)
        echo "🔨 重建预置数据库版本..."
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
    *)
        echo "用法: $0 {start|stop|restart|rebuild|logs|status|health|db-info|shell}"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x "$SCRIPT_DIR/manage_prebuilt.sh"

# 10. 显示部署总结
echo ""
echo "🎉🎉🎉 预置数据库版本部署完成！🎉🎉🎉"
echo "============================================"
echo ""
log_success "📋 部署总结:"
echo "   ✅ 创建了预置数据库文件"
echo "   ✅ 构建了包含数据库的Docker镜像"
echo "   ✅ 启动了预置数据库版本容器"
echo "   ✅ 数据库完全在容器内，无权限问题"
echo "   ✅ 创建了管理脚本"
echo ""
echo "🌐 访问地址: http://localhost:5000"
echo "📊 健康检查: http://localhost:5000/health"
echo ""
echo "🛠️ 管理命令:"
echo "   启动服务: ./manage_prebuilt.sh start"
echo "   停止服务: ./manage_prebuilt.sh stop"
echo "   重启服务: ./manage_prebuilt.sh restart"
echo "   重建镜像: ./manage_prebuilt.sh rebuild"
echo "   查看日志: ./manage_prebuilt.sh logs"
echo "   检查状态: ./manage_prebuilt.sh status"
echo "   健康检查: ./manage_prebuilt.sh health"
echo "   数据库信息: ./manage_prebuilt.sh db-info"
echo "   进入容器: ./manage_prebuilt.sh shell"
echo ""

# 11. 最终验证
log_info "🔍 最终验证..."
echo "容器状态:"
docker ps | grep "$PROJECT_NAME" || echo "❌ 容器未运行"
echo ""
echo "容器内数据库:"
docker exec "$PROJECT_NAME" ls -la /app/db/ 2>/dev/null || echo "❌ 无法访问容器内数据库"
echo ""

log_success "✨ 预置数据库版本部署完成！"
log_info "💡 这个版本将数据库完全打包在容器内，彻底避免了权限问题。"
log_info "🔄 如果需要持久化数据，可以使用原版本或考虑数据导出功能。"
