#!/usr/bin/env python3
"""
创建预置数据库文件
将数据库文件直接打包到Docker镜像中，避免权限问题
"""

import os
import sys
import sqlite3
from pathlib import Path
from datetime import datetime

def create_prebuilt_database():
    """创建预置数据库文件"""
    print("🔧 创建预置数据库文件...")
    
    # 确保db目录存在
    db_dir = Path("db")
    db_dir.mkdir(exist_ok=True)
    
    # 数据库文件路径
    db_path = db_dir / "prebuilt_cache.db"
    
    # 如果文件已存在，先删除
    if db_path.exists():
        db_path.unlink()
        print(f"🗑️ 删除现有数据库文件: {db_path}")
    
    try:
        # 创建数据库连接
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        print("✅ 数据库连接成功")
        
        # 创建LocalJob表（与app_local.py中的模型一致）
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS local_jobs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                remote_job_id INTEGER,
                type VARCHAR(50),
                params TEXT,
                status VARCHAR(20) DEFAULT 'queued',
                prompt_id VARCHAR(64) DEFAULT '',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        print("✅ 创建local_jobs表成功")
        
        # 创建索引
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_remote_job_id ON local_jobs(remote_job_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_prompt_id ON local_jobs(prompt_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_status ON local_jobs(status)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_created_at ON local_jobs(created_at)')
        
        print("✅ 创建索引成功")
        
        # 插入一条测试数据
        cursor.execute('''
            INSERT INTO local_jobs (remote_job_id, type, params, status, prompt_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            0,
            'init',
            '{"message": "Database initialized successfully"}',
            'completed',
            'init_test',
            datetime.now().isoformat()
        ))
        
        print("✅ 插入初始化数据成功")
        
        # 提交事务
        conn.commit()
        
        # 验证数据
        cursor.execute('SELECT COUNT(*) FROM local_jobs')
        count = cursor.fetchone()[0]
        print(f"✅ 数据库验证成功，共有 {count} 条记录")
        
        # 关闭连接
        conn.close()
        
        # 检查文件大小
        file_size = db_path.stat().st_size
        print(f"✅ 数据库文件创建成功")
        print(f"📁 文件路径: {db_path.absolute()}")
        print(f"📏 文件大小: {file_size} bytes")
        
        # 设置文件权限
        os.chmod(str(db_path), 0o666)
        print("✅ 文件权限设置完成 (666)")
        
        return True
        
    except Exception as e:
        print(f"❌ 创建数据库失败: {e}")
        return False

def test_database():
    """测试数据库连接"""
    print("\n🧪 测试数据库连接...")
    
    db_path = Path("db/prebuilt_cache.db")
    
    if not db_path.exists():
        print("❌ 数据库文件不存在")
        return False
    
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        
        # 测试查询
        cursor.execute('SELECT * FROM local_jobs WHERE type = ?', ('init',))
        result = cursor.fetchone()
        
        if result:
            print("✅ 数据库连接测试成功")
            print(f"📊 测试记录: ID={result[0]}, Type={result[2]}, Status={result[4]}")
        else:
            print("❌ 未找到测试记录")
            return False
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ 数据库连接测试失败: {e}")
        return False

def main():
    """主函数"""
    print("🚀 CBIT-AiStudio 预置数据库创建工具")
    print("=" * 50)
    
    # 检查当前目录
    if not Path("app_local.py").exists():
        print("❌ 错误：请在CBIT-AiStudio项目根目录运行此脚本")
        sys.exit(1)
    
    # 创建数据库
    if create_prebuilt_database():
        print("\n✅ 预置数据库创建成功！")
        
        # 测试数据库
        if test_database():
            print("\n🎉 预置数据库已准备就绪，可以打包到Docker镜像中！")
        else:
            print("\n⚠️ 数据库测试失败，请检查")
            sys.exit(1)
    else:
        print("\n❌ 预置数据库创建失败")
        sys.exit(1)

if __name__ == "__main__":
    main()
