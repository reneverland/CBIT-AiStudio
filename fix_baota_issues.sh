#!/bin/bash

# CBIT-AiStudio 宝塔部署问题修复脚本
# 修复Docker Compose版本警告和数据库权限问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[修复]${NC} $1"
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

# 检查是否在项目目录中
check_project_dir() {
    if [ ! -f "docker-compose.yml" ] || [ ! -f "app_local.py" ]; then
        print_error "请在CBIT-AiStudio项目根目录中运行此脚本"
        exit 1
    fi
    print_message "✅ 检测到项目目录"
}

# 修复Docker Compose版本警告
fix_docker_compose_version() {
    print_message "修复Docker Compose版本警告..."
    
    if grep -q "version:" docker-compose.yml; then
        # 备份原文件
        cp docker-compose.yml docker-compose.yml.backup
        
        # 移除version行
        sed -i '/^version:/d' docker-compose.yml
        sed -i '/^$/N;/^\n$/d' docker-compose.yml  # 移除空行
        
        print_message "✅ 已移除过时的version字段"
    else
        print_info "Docker Compose文件已经是最新格式"
    fi
}

# 修复数据库权限问题
fix_database_permissions() {
    print_message "修复数据库权限问题..."
    
    # 确保instance目录存在并有正确权限
    mkdir -p instance
    chmod 777 instance
    
    # 如果数据库文件存在，设置权限
    if [ -f "instance/local_cache.db" ]; then
        chmod 666 instance/local_cache.db
        print_message "✅ 已修复现有数据库文件权限"
    fi
    
    # 确保其他目录权限正确
    mkdir -p downloads static/uploads
    chmod 777 downloads
    chmod 777 static/uploads
    
    print_message "✅ 已修复目录权限"
}

# 停止现有容器
stop_existing_containers() {
    print_message "停止现有容器..."
    
    if docker ps -q --filter "name=cbit-aistudio" | grep -q .; then
        docker stop cbit-aistudio || true
        docker rm cbit-aistudio || true
        print_message "✅ 已停止现有容器"
    else
        print_info "没有运行中的容器"
    fi
}

# 清理Docker镜像缓存
clean_docker_cache() {
    print_message "清理Docker缓存..."
    
    # 删除旧的镜像
    if docker images -q cbit-aistudio 2>/dev/null | grep -q .; then
        docker rmi cbit-aistudio || true
    fi
    
    # 清理构建缓存
    docker builder prune -f || true
    
    print_message "✅ 已清理Docker缓存"
}

# 重新构建和启动
rebuild_and_start() {
    print_message "重新构建和启动应用..."
    
    # 构建新镜像
    docker-compose build --no-cache
    
    if [ $? -eq 0 ]; then
        print_message "✅ 镜像构建成功"
    else
        print_error "镜像构建失败"
        exit 1
    fi
    
    # 启动容器
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_message "✅ 容器启动成功"
    else
        print_error "容器启动失败"
        exit 1
    fi
}

# 验证部署
verify_deployment() {
    print_message "验证部署状态..."
    
    # 等待容器启动
    sleep 10
    
    # 检查容器状态
    if docker ps --filter "name=cbit-aistudio" --filter "status=running" | grep -q cbit-aistudio; then
        print_message "✅ 容器运行正常"
    else
        print_error "容器未正常运行"
        print_info "查看容器日志:"
        docker logs cbit-aistudio
        exit 1
    fi
    
    # 检查健康状态
    print_info "等待应用启动..."
    for i in {1..12}; do
        if curl -f http://localhost:5000/health >/dev/null 2>&1; then
            print_message "✅ 应用健康检查通过"
            break
        else
            if [ $i -eq 12 ]; then
                print_warning "健康检查超时，但容器正在运行"
                print_info "请检查应用日志: docker logs cbit-aistudio"
            else
                print_info "等待应用启动... ($i/12)"
                sleep 5
            fi
        fi
    done
}

# 显示修复结果
show_result() {
    print_message "🎉 修复完成！"
    echo ""
    print_info "修复内容:"
    print_info "  ✅ 移除Docker Compose过时的version字段"
    print_info "  ✅ 修复数据库目录权限问题"
    print_info "  ✅ 重新构建Docker镜像"
    print_info "  ✅ 启动应用容器"
    echo ""
    print_info "应用信息:"
    print_info "  🌐 本地访问: http://localhost:5000"
    print_info "  📊 容器状态: docker ps"
    print_info "  📋 查看日志: docker logs cbit-aistudio"
    print_info "  🔄 重启应用: docker-compose restart"
    echo ""
    print_info "如果仍有问题，请查看容器日志获取详细错误信息"
}

# 主函数
main() {
    print_message "🔧 开始修复CBIT-AiStudio宝塔部署问题"
    echo ""
    
    check_project_dir
    fix_docker_compose_version
    fix_database_permissions
    stop_existing_containers
    clean_docker_cache
    rebuild_and_start
    verify_deployment
    show_result
}

# 执行主函数
main "$@"
