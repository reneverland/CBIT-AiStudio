#!/usr/bin/env python3
"""
本地数据库连接测试脚本
用于验证SQLite数据库权限和连接是否正常
"""

import os
import sys
import sqlite3
from pathlib import Path

def test_database_connection():
    """测试数据库连接"""
    print("🧪 开始测试数据库连接...")
    
    # 确保instance目录存在
    instance_dir = Path("instance")
    instance_dir.mkdir(exist_ok=True)
    
    db_path = instance_dir / "local_cache.db"
    
    try:
        # 测试数据库连接
        print(f"📁 数据库路径: {db_path.absolute()}")
        
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # 创建测试表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS test_connection (
                id INTEGER PRIMARY KEY,
                test_data TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # 插入测试数据
        cursor.execute("INSERT INTO test_connection (test_data) VALUES (?)", ("connection_test",))
        conn.commit()
        
        # 查询测试数据
        cursor.execute("SELECT * FROM test_connection WHERE test_data = ?", ("connection_test",))
        result = cursor.fetchone()
        
        if result:
            print("✅ 数据库连接成功")
            print(f"📊 测试记录ID: {result[0]}")
            
            # 清理测试数据
            cursor.execute("DELETE FROM test_connection WHERE test_data = ?", ("connection_test",))
            conn.commit()
            print("🧹 测试数据已清理")
        else:
            print("❌ 数据库连接失败：无法读取测试数据")
            return False
            
        conn.close()
        
        # 检查文件权限
        stat = db_path.stat()
        print(f"📋 数据库文件权限: {oct(stat.st_mode)[-3:]}")
        print(f"📏 数据库文件大小: {stat.st_size} bytes")
        
        return True
        
    except sqlite3.OperationalError as e:
        print(f"❌ SQLite操作错误: {e}")
        print("💡 这通常是权限问题，请运行修复脚本")
        return False
    except Exception as e:
        print(f"❌ 数据库连接失败: {e}")
        return False

def check_directory_permissions():
    """检查目录权限"""
    print("\n🔍 检查目录权限...")
    
    directories = ["instance", "downloads", "static/uploads"]
    
    for dir_path in directories:
        path = Path(dir_path)
        if path.exists():
            stat = path.stat()
            permissions = oct(stat.st_mode)[-3:]
            print(f"📁 {dir_path}: {permissions}")
        else:
            print(f"📁 {dir_path}: 不存在")

def main():
    """主函数"""
    print("🔧 CBIT-AiStudio 本地数据库测试")
    print("=" * 50)
    
    # 检查当前目录
    if not Path("app_local.py").exists():
        print("❌ 错误：请在CBIT-AiStudio项目根目录运行此脚本")
        sys.exit(1)
    
    # 检查目录权限
    check_directory_permissions()
    
    # 测试数据库连接
    if test_database_connection():
        print("\n✅ 所有测试通过！数据库连接正常")
        print("🚀 可以正常启动应用")
    else:
        print("\n❌ 数据库测试失败")
        print("🔧 建议运行修复脚本: ./fix_database_permissions.sh")
        sys.exit(1)

if __name__ == "__main__":
    main()
