#!/bin/bash

# CBIT-AiStudio 宝塔面板快速部署脚本
# 适用于宝塔Linux面板 7.7.0+

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 检查是否为root用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root用户运行此脚本"
        exit 1
    fi
}

# 检查宝塔面板是否安装
check_baota() {
    if [ ! -f "/www/server/panel/BT-Panel" ]; then
        print_error "未检测到宝塔面板，请先安装宝塔面板"
        print_info "安装命令: curl -sSO http://download.bt.cn/install/install_panel.sh && bash install_panel.sh"
        exit 1
    fi
    print_message "✅ 检测到宝塔面板"
}

# 检查并安装依赖
install_dependencies() {
    print_message "检查并安装依赖..."
    
    # 检查Git
    if ! command -v git &> /dev/null; then
        print_info "安装Git..."
        if command -v yum &> /dev/null; then
            yum install -y git
        elif command -v apt &> /dev/null; then
            apt update && apt install -y git
        fi
    fi
    
    # 检查Python 3.12
    if ! command -v python3.12 &> /dev/null; then
        print_warning "Python 3.12 未安装，请在宝塔面板中安装Python 3.12"
        print_info "路径: 软件商店 -> Python项目管理器 -> 安装"
    fi
    
    # 检查Docker (可选)
    if ! command -v docker &> /dev/null; then
        print_info "Docker未安装，将使用Python直接部署"
        print_info "如需Docker部署，请在宝塔面板软件商店安装Docker"
    else
        print_message "✅ 检测到Docker"
    fi
}

# 创建项目目录
create_project_dir() {
    PROJECT_DIR="/www/wwwroot/CBIT-AiStudio"
    
    print_message "创建项目目录: $PROJECT_DIR"
    
    if [ -d "$PROJECT_DIR" ]; then
        print_warning "项目目录已存在，是否覆盖? (y/N)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            rm -rf "$PROJECT_DIR"
        else
            print_info "取消部署"
            exit 0
        fi
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
}

# 拉取项目代码
clone_project() {
    print_message "拉取项目代码..."
    git clone https://github.com/reneverland/CBIT-AiStudio.git .
    
    if [ $? -eq 0 ]; then
        print_message "✅ 代码拉取成功"
    else
        print_error "代码拉取失败"
        exit 1
    fi
}

# Docker部署
deploy_with_docker() {
    print_message "使用Docker部署..."
    
    if command -v docker-compose &> /dev/null; then
        # 修改docker-compose.yml中的端口映射
        sed -i 's/5000:5000/5000:5000/' docker-compose.yml
        
        # 构建并启动
        docker-compose up -d
        
        if [ $? -eq 0 ]; then
            print_message "✅ Docker部署成功"
            print_info "应用运行在: http://localhost:5000"
        else
            print_error "Docker部署失败"
            exit 1
        fi
    else
        print_error "Docker Compose未安装"
        exit 1
    fi
}

# Python直接部署
deploy_with_python() {
    print_message "使用Python直接部署..."
    
    # 创建虚拟环境
    if command -v python3.12 &> /dev/null; then
        python3.12 -m venv venv
        source venv/bin/activate
        
        # 安装依赖
        pip install -r requirements.txt
        
        # 创建生产环境配置
        cat > .env << EOF
HOST=127.0.0.1
PORT=5000
DEBUG=False
SECRET_KEY=$(openssl rand -hex 32)
SERVER_URL=http://113.106.62.42:9500
EOF
        
        # 设置权限
        chown -R www:www .
        chmod -R 755 .
        chmod 755 instance
        
        # 使用PM2启动 (如果安装了)
        if command -v pm2 &> /dev/null; then
            pm2 start run_local.py --name cbit-aistudio --interpreter python3.12
            pm2 save
            pm2 startup
            print_message "✅ 使用PM2启动成功"
        else
            print_warning "PM2未安装，请手动启动应用或安装PM2"
            print_info "启动命令: python3.12 run_local.py"
        fi
        
    else
        print_error "Python 3.12未安装，请先在宝塔面板中安装"
        exit 1
    fi
}

# 配置Nginx反向代理
configure_nginx() {
    print_message "配置Nginx反向代理..."
    
    DOMAIN=""
    print_info "请输入您的域名 (例: example.com):"
    read -r DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        print_warning "未输入域名，跳过Nginx配置"
        print_info "请手动在宝塔面板中配置反向代理"
        return
    fi
    
    # 创建Nginx配置
    NGINX_CONF="/www/server/panel/vhost/nginx/${DOMAIN}.conf"
    
    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        client_max_body_size 50M;
    }
    
    # 静态文件直接服务
    location /static/ {
        alias /www/wwwroot/CBIT-AiStudio/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # 重载Nginx
    nginx -t && nginx -s reload
    
    if [ $? -eq 0 ]; then
        print_message "✅ Nginx配置成功"
        print_info "请在域名服务商处添加A记录指向服务器IP"
    else
        print_error "Nginx配置失败，请检查配置文件"
    fi
}

# 设置防火墙
setup_firewall() {
    print_message "配置防火墙..."
    
    # 开放必要端口
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=5000/tcp
        firewall-cmd --reload
    elif command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 5000/tcp
    fi
    
    print_message "✅ 防火墙配置完成"
}

# 创建管理脚本
create_management_scripts() {
    print_message "创建管理脚本..."
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/CBIT-AiStudio
if command -v docker-compose &> /dev/null && [ -f docker-compose.yml ]; then
    docker-compose start
else
    pm2 start cbit-aistudio
fi
echo "✅ CBIT-AiStudio 已启动"
EOF
    
    # 创建停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/CBIT-AiStudio
if command -v docker-compose &> /dev/null && [ -f docker-compose.yml ]; then
    docker-compose stop
else
    pm2 stop cbit-aistudio
fi
echo "✅ CBIT-AiStudio 已停止"
EOF
    
    # 创建重启脚本
    cat > restart.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/CBIT-AiStudio
if command -v docker-compose &> /dev/null && [ -f docker-compose.yml ]; then
    docker-compose restart
else
    pm2 restart cbit-aistudio
fi
echo "✅ CBIT-AiStudio 已重启"
EOF
    
    # 创建更新脚本
    cat > update.sh << 'EOF'
#!/bin/bash
cd /www/wwwroot/CBIT-AiStudio

echo "🔄 备份当前版本..."
cp -r . ../CBIT-AiStudio-backup-$(date +%Y%m%d_%H%M%S)

echo "📥 拉取最新代码..."
git pull origin main

echo "🔄 重启服务..."
if command -v docker-compose &> /dev/null && [ -f docker-compose.yml ]; then
    docker-compose restart
else
    source venv/bin/activate
    pip install -r requirements.txt
    pm2 restart cbit-aistudio
fi

echo "✅ 更新完成"
EOF
    
    chmod +x *.sh
    print_message "✅ 管理脚本创建完成"
}

# 显示部署结果
show_result() {
    print_message "🎉 CBIT-AiStudio 部署完成！"
    echo ""
    print_info "项目目录: /www/wwwroot/CBIT-AiStudio"
    print_info "本地访问: http://localhost:5000"
    if [ ! -z "$DOMAIN" ]; then
        print_info "域名访问: http://$DOMAIN"
    fi
    echo ""
    print_info "管理命令:"
    print_info "  启动: ./start.sh"
    print_info "  停止: ./stop.sh"
    print_info "  重启: ./restart.sh"
    print_info "  更新: ./update.sh"
    echo ""
    print_info "宝塔面板配置:"
    print_info "  1. 网站 -> 添加站点 -> 配置反向代理"
    print_info "  2. SSL -> 申请Let's Encrypt证书"
    print_info "  3. 安全 -> 防火墙 -> 开放端口80,443,5000"
    echo ""
    print_warning "请确保:"
    print_warning "  1. 域名DNS解析指向服务器IP"
    print_warning "  2. 服务器防火墙开放相应端口"
    print_warning "  3. 定期备份数据和配置"
}

# 主函数
main() {
    print_message "🚀 开始部署 CBIT-AiStudio 到宝塔面板"
    echo ""
    
    check_root
    check_baota
    install_dependencies
    create_project_dir
    clone_project
    
    # 选择部署方式
    if command -v docker &> /dev/null; then
        print_info "检测到Docker，选择部署方式:"
        print_info "1) Docker部署 (推荐)"
        print_info "2) Python直接部署"
        read -p "请选择 (1/2): " choice
        
        case $choice in
            1)
                deploy_with_docker
                ;;
            2)
                deploy_with_python
                ;;
            *)
                print_warning "无效选择，使用Python直接部署"
                deploy_with_python
                ;;
        esac
    else
        deploy_with_python
    fi
    
    configure_nginx
    setup_firewall
    create_management_scripts
    show_result
}

# 执行主函数
main "$@"
