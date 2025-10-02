# 🚨 CBIT-AiStudio 数据库紧急修复指南

## 问题描述
如果您遇到以下错误：
```
sqlalchemy.exc.OperationalError: (sqlite3.OperationalError) unable to open database file
```

## 🚀 一键紧急修复（推荐）

```bash
# 在项目目录执行
sudo ./emergency_db_fix.sh
```

## 🛠️ 手动修复步骤

如果一键修复失败，请按以下步骤手动修复：

### 1. 强制停止所有服务
```bash
# 停止Docker容器
docker stop $(docker ps -q --filter "name=cbit") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=cbit") 2>/dev/null || true

# 停止docker-compose
docker-compose down --remove-orphans

# 杀死相关进程
pkill -f "run_local.py" || true
```

### 2. 彻底重建目录
```bash
# 备份现有数据
cp -r instance instance_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

# 删除并重建目录
sudo rm -rf instance downloads static/uploads
mkdir -p instance downloads static/uploads

# 设置权限
sudo chmod 777 instance downloads static/uploads
sudo chown -R $(whoami):$(whoami) instance downloads static/uploads

# 创建空数据库文件
touch instance/local_cache.db
sudo chmod 666 instance/local_cache.db
```

### 3. 修复Dockerfile
```bash
# 备份原文件
cp Dockerfile Dockerfile.backup

# 创建修复版本
cat > Dockerfile << 'DOCKER_EOF'
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV HOST=0.0.0.0
ENV PORT=5000
ENV DEBUG=False

RUN apt-get update && apt-get install -y \
    gcc g++ curl sqlite3 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/downloads /app/static/uploads /app/instance && \
    chmod 777 /app/instance /app/downloads /app/static/uploads && \
    touch /app/instance/local_cache.db && \
    chmod 666 /app/instance/local_cache.db

ENV SQLALCHEMY_DATABASE_URI=sqlite:///instance/local_cache.db

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

RUN echo '#!/bin/bash\n\
mkdir -p /app/instance /app/downloads /app/static/uploads\n\
chmod 777 /app/instance /app/downloads /app/static/uploads\n\
touch /app/instance/local_cache.db\n\
chmod 666 /app/instance/local_cache.db\n\
exec python run_local.py' > /app/start.sh && chmod +x /app/start.sh

CMD ["/app/start.sh"]
DOCKER_EOF
```

### 4. 修复docker-compose.yml
```bash
# 备份原文件
cp docker-compose.yml docker-compose.yml.backup

# 创建修复版本
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
    user: "0:0"

networks:
  cbit-network:
    driver: bridge
COMPOSE_EOF
```

### 5. 清理并重建
```bash
# 清理Docker缓存
docker system prune -af
docker builder prune -af

# 重新构建
docker-compose build --no-cache --pull

# 启动服务
docker-compose up -d
```

### 6. 验证修复
```bash
# 检查容器状态
docker ps | grep cbit-aistudio

# 检查日志
docker logs cbit-aistudio

# 健康检查
curl http://localhost:5000/health

# 检查数据库文件
docker exec cbit-aistudio ls -la /app/instance/
```

## 🔍 问题排查

### 检查容器内权限
```bash
docker exec cbit-aistudio ls -la /app/
docker exec cbit-aistudio whoami
docker exec cbit-aistudio id
```

### 测试数据库连接
```bash
docker exec cbit-aistudio python3 -c "
import sqlite3
conn = sqlite3.connect('/app/instance/local_cache.db')
cursor = conn.cursor()
cursor.execute('CREATE TABLE IF NOT EXISTS test (id INTEGER)')
print('数据库连接成功')
conn.close()
"
```

### 检查磁盘空间
```bash
df -h
docker system df
```

## 🆘 最后手段

如果所有方法都失败，尝试完全重新部署：

```bash
# 完全清理
docker system prune -af --volumes
docker builder prune -af

# 重新克隆项目
cd ..
mv CBIT-AiStudio CBIT-AiStudio-broken
git clone https://github.com/reneverland/CBIT-AiStudio.git
cd CBIT-AiStudio

# 恢复数据
cp ../CBIT-AiStudio-broken/instance/* instance/ 2>/dev/null || true

# 运行紧急修复
sudo ./emergency_db_fix.sh
```

## 📞 获取帮助

如果问题仍然存在：

1. 收集错误信息：
   ```bash
   docker logs cbit-aistudio > error.log 2>&1
   ```

2. 检查系统信息：
   ```bash
   uname -a
   docker --version
   docker-compose --version
   df -h
   ```

3. 在GitHub Issues中提交问题，附上错误日志

---

**记住：数据库权限问题通常是由于Docker容器内外权限映射不一致造成的。紧急修复脚本会彻底解决这个问题。**
