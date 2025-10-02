# 宝塔面板部署指南 - CBIT-AiStudio

本指南将详细介绍如何在宝塔面板上部署CBIT-AiStudio项目。

## 📋 前置要求

### 服务器配置
- **操作系统**: CentOS 7+ / Ubuntu 18.04+
- **内存**: 最少 2GB RAM (推荐 4GB+)
- **存储**: 最少 10GB 可用空间
- **CPU**: 2核心以上
- **网络**: 稳定的互联网连接

### 宝塔面板版本
- **宝塔Linux面板**: 7.7.0+
- **Python**: 3.8+ (推荐 3.12)
- **Nginx**: 1.18+
- **PM2**: 进程管理器

## 🚀 部署方式

### 方式一：Docker部署（推荐）

#### 1. 安装Docker
在宝塔面板中安装Docker：
```bash
# 宝塔面板 -> 软件商店 -> 搜索"Docker" -> 安装
# 或者通过SSH命令安装
curl -fsSL https://get.docker.com | bash -s docker
systemctl start docker
systemctl enable docker
```

#### 2. 拉取项目代码
```bash
# SSH连接到服务器
cd /www/wwwroot/
git clone https://github.com/reneverland/CBIT-AiStudio.git
cd CBIT-AiStudio
```

#### 3. 使用Docker Compose部署
```bash
# 构建并启动容器
./deploy.sh build
./deploy.sh start

# 或者手动执行
docker-compose up -d
```

#### 4. 配置Nginx反向代理
在宝塔面板中：
1. **网站** -> **添加站点**
2. **域名**: 填入您的域名
3. **根目录**: `/www/wwwroot/CBIT-AiStudio`
4. **PHP版本**: 纯静态
5. **配置反向代理**:

```nginx
location / {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
```

### 方式二：Python直接部署

#### 1. 安装Python环境
在宝塔面板中：
1. **软件商店** -> 搜索"Python项目管理器" -> 安装
2. 或者通过SSH安装Python 3.12:

```bash
# CentOS/RHEL
yum install python3.12 python3.12-pip -y

# Ubuntu/Debian  
apt update
apt install python3.12 python3.12-pip -y
```

#### 2. 创建Python项目
1. **网站** -> **Python项目** -> **添加Python项目**
2. **项目名称**: CBIT-AiStudio
3. **域名**: 您的域名
4. **项目路径**: `/www/wwwroot/CBIT-AiStudio`
5. **Python版本**: 3.12
6. **框架**: Flask
7. **启动文件**: `run_local.py`

#### 3. 拉取代码和安装依赖
```bash
cd /www/wwwroot/CBIT-AiStudio
git clone https://github.com/reneverland/CBIT-AiStudio.git .

# 创建虚拟环境
python3.12 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

#### 4. 配置环境变量
创建 `.env` 文件：
```bash
# 生产环境配置
HOST=127.0.0.1
PORT=5000
DEBUG=False
SECRET_KEY=your-production-secret-key-here
SERVER_URL=http://113.106.62.42:9500
```

#### 5. 启动应用
```bash
# 使用PM2管理进程
pm2 start run_local.py --name cbit-aistudio --interpreter python3.12
pm2 save
pm2 startup
```

## 🔧 宝塔面板配置

### 1. 防火墙设置
在宝塔面板中：
1. **安全** -> **防火墙** -> **添加端口规则**
2. 开放端口：`5000` (如果直接访问)
3. 开放端口：`80`, `443` (HTTP/HTTPS)

### 2. SSL证书配置
1. **网站** -> **设置** -> **SSL**
2. 选择 **Let's Encrypt** 免费证书
3. 或上传自己的SSL证书

### 3. 域名解析
1. 在域名服务商处添加A记录
2. 指向您的服务器IP地址

## 📊 监控和管理

### 1. 进程监控
```bash
# 查看应用状态
./deploy.sh status

# 查看日志
./deploy.sh logs

# 重启应用
./deploy.sh restart
```

### 2. 宝塔面板监控
1. **监控** -> **负载状态**
2. 查看CPU、内存、磁盘使用情况
3. 设置告警通知

### 3. 备份策略
1. **计划任务** -> **添加任务**
2. 设置定期备份：
   - 数据库备份
   - 网站文件备份
   - 配置文件备份

## 🛠️ 常见问题解决

### 0. 一键修复脚本（推荐）

如果遇到Docker Compose版本警告或数据库权限问题，可以使用一键修复脚本：

```bash
# 在项目目录中运行
./fix_baota_issues.sh
```

**修复内容**:
- ✅ 移除Docker Compose过时的`version`字段
- ✅ 修复数据库目录权限问题 (chmod 777)
- ✅ 清理Docker缓存并重新构建
- ✅ 自动重启应用并验证状态

### 1. 端口占用问题
```bash
# 查看端口占用
netstat -tlnp | grep :5000

# 杀死占用进程
kill -9 <PID>
```

### 2. 权限问题
```bash
# 设置正确的文件权限
chown -R www:www /www/wwwroot/CBIT-AiStudio
chmod -R 755 /www/wwwroot/CBIT-AiStudio
```

### 3. Python依赖问题
```bash
# 重新安装依赖
pip install -r requirements.txt --force-reinstall

# 清理pip缓存
pip cache purge
```

### 4. 数据库权限问题
```bash
# 确保instance目录权限
mkdir -p instance
chmod 755 instance
chown www:www instance
```

## 🔄 更新部署

### 自动更新脚本
创建更新脚本 `update.sh`：
```bash
#!/bin/bash
cd /www/wwwroot/CBIT-AiStudio

# 备份当前版本
cp -r . ../CBIT-AiStudio-backup-$(date +%Y%m%d_%H%M%S)

# 拉取最新代码
git pull origin main

# 重启服务
if command -v docker-compose &> /dev/null; then
    docker-compose restart
else
    pm2 restart cbit-aistudio
fi

echo "✅ 更新完成"
```

### 设置定时更新
在宝塔面板中：
1. **计划任务** -> **Shell脚本**
2. 执行周期：每周
3. 脚本内容：`/www/wwwroot/CBIT-AiStudio/update.sh`

## 📈 性能优化

### 1. Nginx优化
```nginx
# 在网站配置中添加
client_max_body_size 50M;
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;

# 开启gzip压缩
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript;
```

### 2. 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# 优化内核参数
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
sysctl -p
```

## 🔐 安全配置

### 1. 宝塔面板安全
1. 修改默认端口 (8888)
2. 设置复杂的面板密码
3. 开启面板SSL
4. 限制登录IP

### 2. 应用安全
1. 修改默认SECRET_KEY
2. 配置防火墙规则
3. 定期更新系统和软件
4. 监控异常访问

## 📞 技术支持

如果在部署过程中遇到问题：

1. **查看日志**: `./deploy.sh logs`
2. **检查状态**: `./deploy.sh status`
3. **GitHub Issues**: [提交问题](https://github.com/reneverland/CBIT-AiStudio/issues)
4. **宝塔论坛**: [宝塔面板官方论坛](https://www.bt.cn/bbs/)

---

**部署成功后，您可以通过域名访问CBIT-AiStudio应用！** 🎉
