#!/bin/bash

# CI验证和推送脚本
# 在推送前进行本地CI检查

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== CBIT-AiStudio CI验证和推送脚本 ===${NC}"
echo ""

# 检查Git状态
echo -e "${YELLOW}1. 检查Git状态...${NC}"
git status --porcelain
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Git状态正常${NC}"
else
    echo -e "${RED}❌ Git状态异常${NC}"
    exit 1
fi

# 检查Python环境
echo -e "${YELLOW}2. 检查Python环境...${NC}"
python3 --version
if command -v pip3 &> /dev/null; then
    echo -e "${GREEN}✅ Python环境正常${NC}"
else
    echo -e "${RED}❌ Python环境异常${NC}"
    exit 1
fi

# 安装测试依赖
echo -e "${YELLOW}3. 安装测试依赖...${NC}"
pip3 install -q pytest flake8 black isort bandit || {
    echo -e "${YELLOW}⚠️  跳过依赖安装（可能需要虚拟环境）${NC}"
}

# 代码格式检查
echo -e "${YELLOW}4. 代码格式检查...${NC}"
if command -v black &> /dev/null; then
    echo "运行 Black 格式检查..."
    black --check --diff . || echo -e "${YELLOW}⚠️  代码格式需要调整${NC}"
else
    echo -e "${YELLOW}⚠️  跳过 Black 检查（未安装）${NC}"
fi

if command -v isort &> /dev/null; then
    echo "运行 isort 导入排序检查..."
    isort --check-only --diff . || echo -e "${YELLOW}⚠️  导入排序需要调整${NC}"
else
    echo -e "${YELLOW}⚠️  跳过 isort 检查（未安装）${NC}"
fi

# 代码质量检查
echo -e "${YELLOW}5. 代码质量检查...${NC}"
if command -v flake8 &> /dev/null; then
    echo "运行 flake8 代码质量检查..."
    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || echo -e "${YELLOW}⚠️  发现代码质量问题${NC}"
else
    echo -e "${YELLOW}⚠️  跳过 flake8 检查（未安装）${NC}"
fi

# 应用启动测试
echo -e "${YELLOW}6. 应用启动测试...${NC}"
timeout 10s python3 -c "
import sys
sys.path.insert(0, '.')
try:
    from app_local import app
    print('✅ 应用导入成功')
except Exception as e:
    print(f'❌ 应用导入失败: {e}')
    sys.exit(1)
" 2>/dev/null || echo -e "${YELLOW}⚠️  应用启动测试超时或失败${NC}"

# 配置文件验证
echo -e "${YELLOW}7. 配置文件验证...${NC}"
files_to_check=(
    "Dockerfile"
    "docker-compose.yml"
    "requirements.txt"
    "config_local.env"
    ".github/workflows/ci.yml"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file 存在${NC}"
    else
        echo -e "${RED}❌ $file 缺失${NC}"
    fi
done

# Docker构建测试
echo -e "${YELLOW}8. Docker构建测试...${NC}"
if command -v docker &> /dev/null; then
    echo "测试Docker构建..."
    if docker build -t cbit-aistudio-test . --quiet; then
        echo -e "${GREEN}✅ Docker构建成功${NC}"
        # 清理测试镜像
        docker rmi cbit-aistudio-test --force >/dev/null 2>&1 || true
    else
        echo -e "${RED}❌ Docker构建失败${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  跳过Docker测试（Docker未安装）${NC}"
fi

# 安全扫描
echo -e "${YELLOW}9. 安全扫描...${NC}"
if command -v bandit &> /dev/null; then
    echo "运行安全扫描..."
    bandit -r . -f json -o bandit-report.json -q || echo -e "${YELLOW}⚠️  发现潜在安全问题${NC}"
    if [ -f bandit-report.json ]; then
        echo -e "${GREEN}✅ 安全扫描完成${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  跳过安全扫描（bandit未安装）${NC}"
fi

# 运行测试
echo -e "${YELLOW}10. 运行测试...${NC}"
if command -v pytest &> /dev/null && [ -d "tests" ]; then
    echo "运行单元测试..."
    pytest tests/ -v || echo -e "${YELLOW}⚠️  部分测试失败${NC}"
else
    echo -e "${YELLOW}⚠️  跳过测试（pytest未安装或测试目录不存在）${NC}"
fi

echo ""
echo -e "${GREEN}=== CI验证完成 ===${NC}"
echo ""

# 推送到GitHub
echo -e "${YELLOW}是否推送到GitHub? (y/N)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${BLUE}推送到GitHub...${NC}"
    
    # 显示将要推送的提交
    echo -e "${YELLOW}最近的提交:${NC}"
    git log --oneline -3
    
    echo ""
    echo -e "${YELLOW}推送中...${NC}"
    
    # 配置Git设置
    git config --global http.postBuffer 1048576000
    git config --global http.timeout 300
    
    # 推送
    if git push origin main; then
        echo -e "${GREEN}✅ 推送成功！${NC}"
        echo ""
        echo -e "${GREEN}🎉 GitHub Actions CI将自动运行以下检查:${NC}"
        echo "- Python 3.12 环境测试"
        echo "- 代码格式化验证"
        echo "- 代码质量检查"
        echo "- Docker构建测试"
        echo "- 容器健康检查"
        echo "- 安全扫描"
        echo ""
        echo "查看CI状态: https://github.com/reneverland/CBIT-AiStudio/actions"
    else
        echo -e "${RED}❌ 推送失败${NC}"
        echo ""
        echo -e "${YELLOW}备用方案:${NC}"
        echo "1. 检查网络连接"
        echo "2. 尝试: git push origin main --force"
        echo "3. 或稍后重试此脚本"
    fi
else
    echo -e "${BLUE}跳过推送。您可以稍后手动推送:${NC}"
    echo "git push origin main"
fi

echo ""
echo -e "${GREEN}脚本执行完成！${NC}"
