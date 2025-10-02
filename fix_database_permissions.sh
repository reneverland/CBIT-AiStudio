#!/bin/bash

# CBIT-AiStudio 数据库权限修复脚本
# 专门解决 SQLite 数据库权限问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[数据库修复]${NC} $1"
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

# 检查是否为root用户或有sudo权限
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        print_message "✅ 检测到root权限"
        return 0
    elif sudo -n true 2>/dev/null; then
        print_message "✅ 检测到sudo权限"
        return 0
    else
        print_warning "需要root或sudo权限来修复文件权限"
        print_info "请使用: sudo ./fix_database_permissions.sh"
        exit 1
    fi
}

# 检查项目目录
check_project_dir() {
    if [ ! -f "app_local.py" ]; then
        print_error "请在CBIT-AiStudio项目根目录中运行此脚本"
        exit 1
    fi
    print_message "✅ 检测到项目目录: $(pwd)"
}

# 停止运行中的容器
stop_containers() {
    print_message "停止运行中的容器..."
    
    if command -v docker &> /dev/null; then
        # 停止Docker容器
        docker stop cbit-aistudio 2>/dev/null || true
        docker rm cbit-aistudio 2>/dev/null || true
        
        # 停止docker-compose
        if [ -f "docker-compose.yml" ]; then
            docker-compose down 2>/dev/null || true
        fi
        
        print_message "✅ 容器已停止"
    else
        print_info "Docker未安装，跳过容器停止"
    fi
}

# 修复目录权限
fix_directory_permissions() {
    print_message "修复目录权限..."
    
    # 创建必要的目录
    mkdir -p instance downloads static/uploads
    
    # 设置目录权限
    if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
        # 使用root权限设置
        if [ "$EUID" -ne 0 ]; then
            SUDO_CMD="sudo"
        else
            SUDO_CMD=""
        fi
        
        $SUDO_CMD chmod 777 instance
        $SUDO_CMD chmod 777 downloads  
        $SUDO_CMD chmod 777 static/uploads
        $SUDO_CMD chown -R $(whoami):$(whoami) instance downloads static/uploads 2>/dev/null || true
        
        print_message "✅ 目录权限已修复 (777)"
    else
        # 普通用户权限设置
        chmod 755 instance downloads static/uploads 2>/dev/null || true
        print_message "✅ 目录权限已设置 (755)"
    fi
    
    # 显示当前权限
    print_info "当前目录权限:"
    ls -la instance downloads static/uploads 2>/dev/null || true
}

# 修复数据库文件权限
fix_database_file_permissions() {
    print_message "修复数据库文件权限..."
    
    DB_FILE="instance/local_cache.db"
    
    if [ -f "$DB_FILE" ]; then
        print_info "发现现有数据库文件: $DB_FILE"
        
        # 备份数据库
        cp "$DB_FILE" "$DB_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        print_message "✅ 数据库已备份"
        
        # 修复文件权限
        if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
            if [ "$EUID" -ne 0 ]; then
                SUDO_CMD="sudo"
            else
                SUDO_CMD=""
            fi
            
            $SUDO_CMD chmod 666 "$DB_FILE"
            $SUDO_CMD chown $(whoami):$(whoami) "$DB_FILE" 2>/dev/null || true
        else
            chmod 644 "$DB_FILE" 2>/dev/null || true
        fi
        
        print_message "✅ 数据库文件权限已修复"
        ls -la "$DB_FILE"
    else
        print_info "数据库文件不存在，将在应用启动时创建"
    fi
}

# 测试数据库连接
test_database_connection() {
    print_message "测试数据库连接..."
    
    # 创建测试脚本
    cat > test_db.py << 'PYTHON_EOF'
import os
import sqlite3
import sys

# 设置数据库路径
db_path = "instance/local_cache.db"

try:
    # 确保目录存在
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    
    # 测试连接
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 创建测试表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS test_table (
            id INTEGER PRIMARY KEY,
            test_data TEXT
        )
    ''')
    
    # 插入测试数据
    cursor.execute("INSERT INTO test_table (test_data) VALUES (?)", ("test_connection",))
    conn.commit()
    
    # 查询测试数据
    cursor.execute("SELECT * FROM test_table WHERE test_data = ?", ("test_connection",))
    result = cursor.fetchone()
    
    if result:
        print("✅ 数据库连接测试成功")
        # 清理测试数据
        cursor.execute("DELETE FROM test_table WHERE test_data = ?", ("test_connection",))
        conn.commit()
    else:
        print("❌ 数据库写入测试失败")
        sys.exit(1)
    
    conn.close()
    print(f"✅ 数据库文件: {os.path.abspath(db_path)}")
    
except Exception as e:
    print(f"❌ 数据库连接失败: {e}")
    sys.exit(1)
PYTHON_EOF
    
    # 运行测试
    if python3 test_db.py; then
        print_message "✅ 数据库连接测试通过"
    else
        print_error "数据库连接测试失败"
        return 1
    fi
    
    # 清理测试文件
    rm -f test_db.py
}

# 修复Docker配置
fix_docker_config() {
    if [ -f "Dockerfile" ]; then
        print_message "检查Docker配置..."
        
        # 检查Dockerfile中的权限设置
        if grep -q "chmod 777" Dockerfile; then
            print_message "✅ Dockerfile权限配置正确"
        else
            print_warning "Dockerfile可能需要更新权限设置"
            print_info "建议运行: ./fix_baota_issues.sh"
        fi
    fi
}

# 创建启动脚本
create_startup_script() {
    print_message "创建数据库启动脚本..."
    
    cat > start_with_db_fix.sh << 'STARTUP_EOF'
#!/bin/bash

# 启动前数据库权限检查脚本

echo "🔧 启动前检查数据库权限..."

# 确保目录存在并有正确权限
mkdir -p instance downloads static/uploads
chmod 777 instance downloads static/uploads 2>/dev/null || chmod 755 instance downloads static/uploads

# 如果数据库文件存在，确保权限正确
if [ -f "instance/local_cache.db" ]; then
    chmod 666 instance/local_cache.db 2>/dev/null || chmod 644 instance/local_cache.db
fi

echo "✅ 数据库权限检查完成"

# 启动应用
if [ -f "docker-compose.yml" ]; then
    echo "🚀 使用Docker启动..."
    docker-compose up -d
elif [ -f "venv/bin/activate" ]; then
    echo "🚀 使用Python虚拟环境启动..."
    source venv/bin/activate
    python3 run_local.py
else
    echo "🚀 直接启动..."
    python3 run_local.py
fi
STARTUP_EOF
    
    chmod +x start_with_db_fix.sh
    print_message "✅ 启动脚本已创建: start_with_db_fix.sh"
}

# 显示修复结果
show_result() {
    print_message "🎉 数据库权限修复完成！"
    echo ""
    print_info "修复内容:"
    print_info "  ✅ 目录权限已修复 (instance, downloads, static/uploads)"
    print_info "  ✅ 数据库文件权限已修复"
    print_info "  ✅ 数据库连接测试通过"
    print_info "  ✅ 创建了启动脚本"
    echo ""
    print_info "启动应用:"
    print_info "  🚀 推荐使用: ./start_with_db_fix.sh"
    print_info "  🚀 或者使用: ./deploy.sh start"
    print_info "  🚀 Docker方式: docker-compose up -d"
    echo ""
    print_info "如果仍有问题:"
    print_info "  📋 查看日志: docker logs cbit-aistudio"
    print_info "  🔧 运行完整修复: ./fix_baota_issues.sh"
    print_info "  📞 检查系统日志: journalctl -u docker"
}

# 主函数
main() {
    print_message "🔧 开始修复CBIT-AiStudio数据库权限问题"
    echo ""
    
    check_project_dir
    check_permissions
    stop_containers
    fix_directory_permissions
    fix_database_file_permissions
    
    if test_database_connection; then
        fix_docker_config
        create_startup_script
        show_result
    else
        print_error "数据库修复失败，请检查系统权限和磁盘空间"
        exit 1
    fi
}

# 执行主函数
main "$@"
