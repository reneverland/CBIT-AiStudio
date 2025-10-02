#!/bin/bash
echo "🚀 启动BaiduCBIT本地版本v2.0..."
echo "📱 完全兼容服务器端UI和API"
echo

# 检查Python是否安装
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到Python3，请先安装Python 3.7+"
    exit 1
fi

# 检查依赖是否安装
echo "📦 检查依赖..."
if ! python3 -c "import flask" &> /dev/null; then
    echo "📥 安装依赖..."
    python3 -m pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        echo "❌ 依赖安装失败，尝试使用国内镜像..."
        python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt
        if [ $? -ne 0 ]; then
            echo "❌ 依赖安装失败"
            exit 1
        fi
    fi
fi

echo "✅ 依赖检查完成"
echo

# 启动应用
echo "🌐 启动应用..."
echo "📡 将连接到服务器: http://113.106.62.42:9500"
echo "🔗 本地访问地址: http://127.0.0.1:5000"
echo
python3 run_local.py
