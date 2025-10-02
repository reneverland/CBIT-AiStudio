#!/bin/bash

# CBIT-AiStudio 紧急数据库修复脚本
# 彻底解决 SQLite 数据库权限问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[紧急修复]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

# 强制停止所有相关容器和进程
force_stop_all() {
    print_message "强制停止所有相关服务..."
    
    # 停止Docker容器
    docker stop $(docker ps -q --filter "name=cbit") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=cbit") 2>/dev/null || true
    
    # 停止docker-compose
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 杀死可能占用端口的进程
    pkill -f "run_local.py" 2>/dev/null || true
    pkill -f "python.*5000" 2>/dev/null || true
    
    # 清理Docker网络
    docker network prune -f 2>/dev/null || true
    
    print_message "✅ 所有服务已强制停止"
}

# 彻底清理和重建目录
rebuild_directories() {
    print_message "彻底重建目录结构..."
    
    # 备份现有数据
    if [ -d "instance" ]; then
        cp -r instance instance_emergency_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    fi
    
    # 删除并重建目录
    sudo rm -rf instance downloads static/uploads 2>/dev/null || true
    
    # 重新创建目录
    mkdir -p instance downloads static/uploads
    
    # 设置最宽松的权限
    sudo chmod 777 instance downloads static/uploads
    sudo chown -R $(whoami):$(whoami) instance downloads static/uploads 2>/dev/null || true
    
    # 创建空的数据库文件并设置权限
    touch instance/local_cache.db
    sudo chmod 666 instance/local_cache.db
    sudo chown $(whoami):$(whoami) instance/local_cache.db 2>/dev/null || true
    
    print_message "✅ 目录结构已重建"
    ls -la instance downloads static/uploads
}

# 修复Docker配置文件
fix_docker_files() {
    print_message "修复Docker配置文件..."
    
    # 备份原文件
    cp Dockerfile Dockerfile.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    
    # 创建修复版本的Dockerfile
    cat > Dockerfile << 'DOCKER_EOF'
# 使用Python 3.12官方镜像
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
    gcc \
    g++ \
    curl \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 创建必要的目录并设置最宽松权限
RUN mkdir -p /app/downloads /app/static/uploads /app/instance && \
    chmod 777 /app/instance && \
    chmod 777 /app/downloads && \
    chmod 777 /app/static/uploads && \
    touch /app/instance/local_cache.db && \
    chmod 666 /app/instance/local_cache.db

# 设置数据库路径为容器内默认位置
ENV SQLALCHEMY_DATABASE_URI=sqlite:///instance/local_cache.db

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# 启动前权限检查脚本
RUN echo '#!/bin/bash\n\
echo "🔧 启动前权限检查..."\n\
mkdir -p /app/instance /app/downloads /app/static/uploads\n\
chmod 777 /app/instance /app/downloads /app/static/uploads\n\
touch /app/instance/local_cache.db\n\
chmod 666 /app/instance/local_cache.db\n\
echo "✅ 权限检查完成"\n\
exec python run_local.py' > /app/start.sh && chmod +x /app/start.sh

# 启动命令
CMD ["/app/start.sh"]
DOCKER_EOF

    # 创建修复版本的docker-compose.yml
    cat > docker-compose.yml << 'COMPOSE_EOF'
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
      # 持久化数据库和上传文件，使用最宽松权限
      - ./instance:/app/instance:rw
      - ./downloads:/app/downloads:rw
      - ./static/uploads:/app/static/uploads:rw
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - cbit-network
    # 添加特权模式以确保权限
    privileged: false
    user: "0:0"  # 使用root用户运行

networks:
  cbit-network:
    driver: bridge
COMPOSE_EOF

    print_message "✅ Docker配置文件已修复"
}

# 清理Docker缓存和镜像
clean_docker_cache() {
    print_message "清理Docker缓存..."
    
    # 删除相关镜像
    docker rmi $(docker images -q "*cbit*") 2>/dev/null || true
    docker rmi $(docker images -q "cbit-aistudio*") 2>/dev/null || true
    
    # 清理构建缓存
    docker builder prune -af
    docker system prune -f
    
    print_message "✅ Docker缓存已清理"
}

# 重新构建和启动
rebuild_and_start() {
    print_message "重新构建Docker镜像..."
    
    # 构建新镜像
    docker-compose build --no-cache --pull
    
    if [ $? -ne 0 ]; then
        print_error "Docker镜像构建失败"
        exit 1
    fi
    
    print_message "✅ Docker镜像构建成功"
    
    # 启动容器
    print_message "启动容器..."
    docker-compose up -d
    
    if [ $? -ne 0 ]; then
        print_error "容器启动失败"
        print_info "查看构建日志:"
        docker-compose logs
        exit 1
    fi
    
    print_message "✅ 容器启动成功"
}

# 验证修复结果
verify_fix() {
    print_message "验证修复结果..."
    
    # 等待容器完全启动
    print_info "等待容器启动..."
    sleep 30
    
    # 检查容器状态
    if ! docker ps | grep -q cbit-aistudio; then
        print_error "容器未正常运行"
        print_info "容器日志:"
        docker logs cbit-aistudio
        return 1
    fi
    
    print_message "✅ 容器运行正常"
    
    # 检查数据库文件
    print_info "检查容器内数据库文件..."
    docker exec cbit-aistudio ls -la /app/instance/ || true
    
    # 测试数据库连接
    print_info "测试数据库连接..."
    docker exec cbit-aistudio python3 -c "
import sqlite3
import os
try:
    conn = sqlite3.connect('/app/instance/local_cache.db')
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE IF NOT EXISTS test (id INTEGER)')
    cursor.execute('INSERT INTO test (id) VALUES (1)')
    conn.commit()
    cursor.execute('SELECT * FROM test')
    result = cursor.fetchall()
    conn.close()
    print('✅ 数据库连接测试成功:', result)
except Exception as e:
    print('❌ 数据库连接测试失败:', e)
    exit(1)
"
    
    # 健康检查
    print_info "执行健康检查..."
    for i in {1..10}; do
        if curl -f http://localhost:5000/health >/dev/null 2>&1; then
            print_message "✅ 应用健康检查通过"
            
            # 获取健康信息
            HEALTH_INFO=$(curl -s http://localhost:5000/health 2>/dev/null || echo "无法获取健康信息")
            print_info "健康状态: $HEALTH_INFO"
            return 0
        else
            print_info "等待应用启动... ($i/10)"
            sleep 10
        fi
    done
    
    print_warning "健康检查超时，但容器可能仍在启动"
    print_info "请查看容器日志: docker logs cbit-aistudio"
    return 1
}

# 创建监控脚本
create_monitoring_script() {
    print_message "创建监控脚本..."
    
    cat > monitor_db.sh << 'MONITOR_EOF'
#!/bin/bash

# 数据库监控脚本

echo "🔍 CBIT-AiStudio 数据库状态监控"
echo "================================"

# 检查容器状态
echo "📦 容器状态:"
docker ps --filter "name=cbit-aistudio" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查数据库文件
echo ""
echo "💾 数据库文件状态:"
if docker exec cbit-aistudio test -f /app/instance/local_cache.db 2>/dev/null; then
    docker exec cbit-aistudio ls -la /app/instance/local_cache.db
    echo "✅ 数据库文件存在"
else
    echo "❌ 数据库文件不存在"
fi

# 检查目录权限
echo ""
echo "📁 目录权限:"
docker exec cbit-aistudio ls -la /app/ | grep -E "(instance|downloads|static)"

# 测试数据库连接
echo ""
echo "🔗 数据库连接测试:"
docker exec cbit-aistudio python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('/app/instance/local_cache.db')
    cursor = conn.cursor()
    cursor.execute('SELECT name FROM sqlite_master WHERE type=\"table\"')
    tables = cursor.fetchall()
    conn.close()
    print('✅ 数据库连接正常')
    print('📋 数据表:', [t[0] for t in tables] if tables else '无表')
except Exception as e:
    print('❌ 数据库连接失败:', e)
" 2>/dev/null || echo "❌ 无法执行数据库测试"

# 健康检查
echo ""
echo "🏥 应用健康检查:"
if curl -f http://localhost:5000/health >/dev/null 2>&1; then
    echo "✅ 应用响应正常"
    curl -s http://localhost:5000/health | python3 -m json.tool 2>/dev/null || echo "健康检查响应异常"
else
    echo "❌ 应用无响应"
fi

echo ""
echo "📋 如需查看详细日志: docker logs cbit-aistudio"
MONITOR_EOF

    chmod +x monitor_db.sh
    print_message "✅ 监控脚本已创建: monitor_db.sh"
}

# 显示修复结果
show_emergency_result() {
    print_message "🎉 紧急修复完成！"
    echo ""
    print_info "修复内容:"
    print_info "  🛑 强制停止所有相关服务"
    print_info "  📁 彻底重建目录结构 (777权限)"
    print_info "  🐳 修复Docker配置文件"
    print_info "  🧹 清理Docker缓存"
    print_info "  🔨 重新构建镜像"
    print_info "  🚀 启动容器"
    print_info "  ✅ 验证数据库连接"
    echo ""
    print_info "管理命令:"
    print_info "  📊 监控状态: ./monitor_db.sh"
    print_info "  📋 查看日志: docker logs cbit-aistudio"
    print_info "  🔄 重启服务: docker-compose restart"
    print_info "  🛑 停止服务: docker-compose down"
    echo ""
    print_info "访问地址: http://localhost:5000"
    print_warning "如果仍有问题，请运行 ./monitor_db.sh 查看详细状态"
}

# 主函数
main() {
    print_message "🚨 开始紧急修复CBIT-AiStudio数据库问题"
    print_warning "此操作将彻底重建Docker环境和目录结构"
    echo ""
    
    # 确认操作
    print_warning "确认继续紧急修复? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "紧急修复已取消"
        exit 0
    fi
    
    force_stop_all
    rebuild_directories
    fix_docker_files
    clean_docker_cache
    rebuild_and_start
    
    if verify_fix; then
        create_monitoring_script
        show_emergency_result
    else
        print_error "紧急修复验证失败"
        print_info "请查看容器日志: docker logs cbit-aistudio"
        print_info "或运行监控脚本: ./monitor_db.sh"
        exit 1
    fi
}

# 执行主函数
main "$@"
