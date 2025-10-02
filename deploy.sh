#!/bin/bash

# CBIT-AiStudio 部署脚本
# 用于快速部署和管理容器化应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${GREEN}[CBIT-AiStudio]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
}

# 构建镜像
build() {
    print_message "开始构建 CBIT-AiStudio 镜像..."
    docker-compose build
    print_message "镜像构建完成"
}

# 启动服务
start() {
    print_message "启动 CBIT-AiStudio 服务..."
    docker-compose up -d
    print_message "服务启动完成"
    print_info "访问地址: http://localhost:5000"
    print_info "查看日志: ./deploy.sh logs"
    print_info "停止服务: ./deploy.sh stop"
}

# 停止服务
stop() {
    print_message "停止 CBIT-AiStudio 服务..."
    docker-compose down
    print_message "服务已停止"
}

# 重启服务
restart() {
    print_message "重启 CBIT-AiStudio 服务..."
    docker-compose restart
    print_message "服务重启完成"
}

# 查看日志
logs() {
    print_message "显示服务日志..."
    docker-compose logs -f
}

# 查看状态
status() {
    print_message "服务状态:"
    docker-compose ps
    echo ""
    print_info "健康检查:"
    curl -s http://localhost:5000/health | python3 -m json.tool 2>/dev/null || print_warning "服务未响应"
}

# 清理
clean() {
    print_warning "这将删除所有容器和镜像，确定继续吗? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_message "清理容器和镜像..."
        docker-compose down --rmi all --volumes --remove-orphans
        print_message "清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 更新
update() {
    print_message "更新 CBIT-AiStudio..."
    git pull origin main
    docker-compose down
    docker-compose build --no-cache
    docker-compose up -d
    print_message "更新完成"
}

# 备份数据
backup() {
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    print_message "创建数据备份到 $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r instance "$BACKUP_DIR/"
    cp -r downloads "$BACKUP_DIR/"
    cp -r static/uploads "$BACKUP_DIR/"
    print_message "备份完成: $BACKUP_DIR"
}

# 显示帮助
show_help() {
    echo "CBIT-AiStudio 部署管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  build     构建Docker镜像"
    echo "  start     启动服务"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  logs      查看日志"
    echo "  status    查看服务状态"
    echo "  clean     清理容器和镜像"
    echo "  update    更新应用"
    echo "  backup    备份数据"
    echo "  help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build && $0 start    # 构建并启动"
    echo "  $0 logs                 # 查看实时日志"
    echo "  $0 status               # 检查服务状态"
}

# 主逻辑
main() {
    check_docker
    
    case "${1:-help}" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            logs
            ;;
        status)
            status
            ;;
        clean)
            clean
            ;;
        update)
            update
            ;;
        backup)
            backup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
