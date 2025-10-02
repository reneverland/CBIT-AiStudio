@echo off
chcp 65001 >nul
echo 🚀 启动BaiduCBIT本地版本v2.0...
echo 📱 完全兼容服务器端UI和API
echo.

REM 检查Python是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 未找到Python，请先安装Python 3.7+
    echo 下载地址: https://www.python.org/downloads/
    pause
    exit /b 1
)

REM 检查依赖是否安装
echo 📦 检查依赖...
python -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo 📥 安装依赖...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ❌ 依赖安装失败，尝试使用国内镜像...
        pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt
        if errorlevel 1 (
            echo ❌ 依赖安装失败
            pause
            exit /b 1
        )
    )
)

echo ✅ 依赖检查完成
echo.

REM 启动应用
echo 🌐 启动应用...
echo 📡 将连接到服务器: http://113.106.62.42:9500
echo 🔗 本地访问地址: http://127.0.0.1:5000
echo.
python run_local.py

pause
