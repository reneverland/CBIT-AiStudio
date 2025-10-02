# CBIT-AiStudio 部署指南

## 🚀 快速部署

### 方式一：Docker Compose（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/reneverland/CBIT-AiStudio.git
cd CBIT-AiStudio

# 2. 构建并启动
./deploy.sh build
./deploy.sh start

# 3. 访问应用
# 浏览器打开: http://localhost:5000
```

### 方式二：Docker 手动部署

```bash
# 构建镜像
docker build -t cbit-aistudio .

# 运行容器
docker run -d \
  --name cbit-aistudio \
  -p 5000:5000 \
  -v ./instance:/app/instance \
  -v ./downloads:/app/downloads \
  -v ./static/uploads:/app/static/uploads \
  cbit-aistudio
```

### 方式三：本地开发

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 启动应用
python run_local.py
```

## 📋 系统要求

- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **内存**: 最少 2GB RAM
- **存储**: 最少 5GB 可用空间
- **网络**: 需要访问远程AI服务器

## ⚙️ 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `HOST` | `0.0.0.0` | 服务监听地址 |
| `PORT` | `5000` | 服务端口 |
| `DEBUG` | `false` | 调试模式 |
| `SERVER_URL` | `http://113.106.62.42:9500` | 远程AI服务器地址 |
| `SECRET_KEY` | `production-secret-key-2025` | Flask密钥 |

### 数据持久化

容器内的以下目录会被持久化：
- `/app/instance` - 数据库文件
- `/app/downloads` - 下载文件
- `/app/static/uploads` - 上传文件

## 🛠️ 管理命令

使用 `./deploy.sh` 脚本管理应用：

```bash
./deploy.sh build     # 构建镜像
./deploy.sh start     # 启动服务
./deploy.sh stop      # 停止服务
./deploy.sh restart   # 重启服务
./deploy.sh logs      # 查看日志
./deploy.sh status    # 查看状态
./deploy.sh backup    # 备份数据
./deploy.sh clean     # 清理容器和镜像
./deploy.sh update    # 更新应用
```

## 🔧 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口占用
   lsof -i :5000
   # 修改端口
   export PORT=5001
   ./deploy.sh restart
   ```

2. **无法连接远程服务器**
   ```bash
   # 检查网络连接
   curl -I http://113.106.62.42:9500/health
   # 查看应用日志
   ./deploy.sh logs
   ```

3. **数据库问题**
   ```bash
   # 重置数据库
   rm -f instance/local_cache.db
   ./deploy.sh restart
   ```

### 健康检查

访问健康检查端点：
```bash
curl http://localhost:5000/health
```

正常响应：
```json
{
  "status": "ok",
  "local": true,
  "server": true,
  "server_url": "http://113.106.62.42:9500",
  "timestamp": "2025-10-02T13:45:00.000000"
}
```

## 🔒 安全建议

1. **生产环境部署**
   - 修改默认的 `SECRET_KEY`
   - 使用反向代理（Nginx）
   - 启用HTTPS
   - 限制访问IP

2. **数据备份**
   ```bash
   # 定期备份
   ./deploy.sh backup
   
   # 自动备份（crontab）
   0 2 * * * cd /path/to/CBIT-AiStudio && ./deploy.sh backup
   ```

## 📊 监控

### 日志查看
```bash
# 实时日志
./deploy.sh logs

# Docker原生命令
docker logs -f cbit-aistudio
```

### 性能监控
```bash
# 容器资源使用
docker stats cbit-aistudio

# 系统资源
htop
```

## 🆙 更新升级

```bash
# 自动更新
./deploy.sh update

# 手动更新
git pull origin main
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 📞 技术支持

- **GitHub Issues**: [https://github.com/reneverland/CBIT-AiStudio/issues](https://github.com/reneverland/CBIT-AiStudio/issues)
- **开发者**: [@reneverland](https://github.com/reneverland)
- **文档**: 查看项目README.md获取详细技术信息

---

*部署遇到问题？请在GitHub Issues中提交问题，我们会及时回复。*
