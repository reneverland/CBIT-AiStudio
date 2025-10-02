#!/usr/bin/env python3
"""
BaiduCBIT 本地版本启动脚本 v2.0
"""

import os
import sys
from pathlib import Path

# 添加当前目录到Python路径
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

# 设置环境变量文件
env_file = current_dir / 'config_local.env'
if env_file.exists():
    from dotenv import load_dotenv
    load_dotenv(dotenv_path=env_file)

# 导入并运行应用
from app_local import main

if __name__ == '__main__':
    main()
