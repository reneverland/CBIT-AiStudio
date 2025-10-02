#!/bin/bash

# GitHub推送脚本
# 用于将CBIT-AiStudio项目推送到GitHub

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== CBIT-AiStudio GitHub推送脚本 ===${NC}"
echo ""

# 检查Git状态
echo -e "${YELLOW}检查Git状态...${NC}"
git status

echo ""
echo -e "${YELLOW}当前远程仓库配置:${NC}"
git remote -v

echo ""
echo -e "${YELLOW}最近的提交记录:${NC}"
git log --oneline -5

echo ""
echo -e "${GREEN}开始推送到GitHub...${NC}"

# 配置Git设置以优化推送
echo "配置Git设置..."
git config --global http.postBuffer 1048576000
git config --global http.timeout 300
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
git config --global http.sslVerify true

# 尝试推送
echo "推送到GitHub仓库..."
if git push -u origin main; then
    echo -e "${GREEN}✅ 推送成功！${NC}"
    echo "GitHub仓库地址: https://github.com/reneverland/CBIT-AiStudio"
else
    echo -e "${RED}❌ 推送失败${NC}"
    echo ""
    echo -e "${YELLOW}备用方案:${NC}"
    echo "1. 检查网络连接"
    echo "2. 尝试使用VPN或更换网络"
    echo "3. 手动执行: git push origin main --force"
    echo "4. 或者稍后重试此脚本"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 CBIT-AiStudio项目已成功推送到GitHub！${NC}"
echo ""
echo "项目信息:"
echo "- 仓库地址: https://github.com/reneverland/CBIT-AiStudio"
echo "- 分支: main"
echo "- 最新提交: $(git log -1 --pretty=format:'%h - %s')"
echo ""
echo "下一步:"
echo "1. 访问GitHub仓库查看代码"
echo "2. 设置仓库描述和标签"
echo "3. 配置GitHub Pages（如需要）"
echo "4. 添加协作者（如需要）"
