#!/usr/bin/env python3
"""
BaiduCBIT 本地版本 - 完全兼容服务器端API
连接远程服务器进行AI图像生成
"""

import os
import sys
import json
import time
import base64
import hashlib
import hmac
import urllib.parse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

# 添加当前目录到Python路径
sys.path.insert(0, str(Path(__file__).parent))

from flask import Flask, render_template, request, jsonify, send_from_directory, Response
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from dotenv import load_dotenv
import requests

# 加载环境变量
load_dotenv(dotenv_path='config_local.env')

class RemoteAPIClient:
    """远程API客户端 - 完全代理服务器端API"""
    
    def __init__(self, server_url: str = None):
        self.server_url = server_url or os.getenv('SERVER_URL', 'http://113.106.62.42:9500')
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'BaiduCBIT-Local/2.0'
        })
    
    def proxy_request(self, method: str, path: str, **kwargs) -> requests.Response:
        """代理请求到远程服务器"""
        url = f"{self.server_url}{path}"
        return self.session.request(method, url, **kwargs)
    
    def health_check(self) -> bool:
        """健康检查"""
        try:
            response = self.session.get(f"{self.server_url}/health", timeout=10)
            return response.status_code == 200
        except:
            return False

# 创建Flask应用
app = Flask(__name__, 
           template_folder='templates',
           static_folder='static')
CORS(app)

# 配置
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'local-dev-key')
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB

# 创建远程API客户端
api_client = RemoteAPIClient()

# 本地SQLite数据库（用于缓存）
# 在CI环境中直接使用内存数据库
ci_env = os.getenv('CI', '').lower() == 'true'
if ci_env:
    database_uri = 'sqlite:///:memory:'
    print("🔧 CI环境检测到，使用内存数据库")
else:
    database_uri = os.getenv('SQLALCHEMY_DATABASE_URI', 'sqlite:///instance/local_cache.db')
    # 确保数据库目录存在
    db_path = database_uri.replace('sqlite:///', '')
    db_dir = os.path.dirname(db_path)
    if db_dir:
        os.makedirs(db_dir, exist_ok=True)

app.config['SQLALCHEMY_DATABASE_URI'] = database_uri
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# 本地缓存模型
class LocalJob(db.Model):
    __tablename__ = "local_jobs"
    id = db.Column(db.Integer, primary_key=True)
    remote_job_id = db.Column(db.Integer, index=True)
    type = db.Column(db.String(50))
    params = db.Column(db.Text)
    status = db.Column(db.String(20), default="queued")
    prompt_id = db.Column(db.String(64), default="")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# 路由定义 - 完全兼容服务器端
@app.route("/", methods=["GET"])
def index():
    """主页"""
    return render_template("index.html")

@app.route("/api/upload", methods=["POST"])
def api_upload():
    """文件上传代理"""
    try:
        # 代理到远程服务器
        files = {}
        if 'file' in request.files:
            file = request.files['file']
            files['file'] = (file.filename, file.stream, file.content_type)
        
        response = api_client.proxy_request('POST', '/api/upload', files=files, timeout=60)
        
        return jsonify(response.json()), response.status_code
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/api/generate", methods=["POST"])
def generate():
    """生图API代理"""
    try:
        data = request.get_json()
        
        # 代理到远程服务器
        response = api_client.proxy_request('POST', '/api/generate', json=data, timeout=120)
        result = response.json()
        
        # 本地缓存任务信息
        if response.status_code == 200 and 'job_id' in result:
            local_job = LocalJob(
                remote_job_id=result['job_id'],
                type=data.get('mode', 'unknown'),
                params=json.dumps(data, ensure_ascii=False),
                status='queued',
                prompt_id=result.get('prompt_id', '')
            )
            db.session.add(local_job)
            db.session.commit()
        
        return jsonify(result), response.status_code
        
    except Exception as e:
        return jsonify({"error": f"生成失败: {str(e)}"}), 500

@app.route("/api/result", methods=["GET"])
def api_result():
    """获取生成结果代理"""
    try:
        # 获取参数
        prompt_id = request.args.get("prompt_id", "")
        
        # 代理到远程服务器
        response = api_client.proxy_request('GET', '/api/result', params={'prompt_id': prompt_id}, timeout=30)
        
        return jsonify(response.json()), response.status_code
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/api/proxy/view", methods=["GET"])
def api_proxy_view():
    """代理ComfyUI图像查看"""
    try:
        # 获取参数
        params = {
            'filename': request.args.get('filename', ''),
            'type': request.args.get('type', 'output'),
            'subfolder': request.args.get('subfolder', '')
        }
        
        # 代理到远程服务器
        response = api_client.proxy_request('GET', '/api/proxy/view', params=params, timeout=60, stream=True)
        
        if response.status_code != 200:
            return Response(response.content, status=response.status_code)
        
        content_type = response.headers.get('Content-Type', 'image/png')
        return Response(response.content, mimetype=content_type)
        
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/api/video/generate", methods=["POST"])
def api_video_generate():
    """视频生成API代理"""
    try:
        data = request.get_json()
        
        # 代理到远程服务器
        response = api_client.proxy_request('POST', '/api/video/generate', json=data, timeout=120)
        
        return jsonify(response.json()), response.status_code
        
    except Exception as e:
        return jsonify({"error": f"视频生成失败: {str(e)}"}), 500

@app.route("/api/video/status/<task_id>", methods=["GET"])
def api_video_status(task_id):
    """视频任务状态查询代理"""
    try:
        # 代理到远程服务器
        response = api_client.proxy_request('GET', f'/api/video/status/{task_id}', timeout=30)
        
        return jsonify(response.json()), response.status_code
        
    except Exception as e:
        return jsonify({"error": f"查询失败: {str(e)}"}), 500

@app.route("/health", methods=["GET"])
def health():
    """健康检查"""
    # 在CI环境中跳过远程服务器检查以加快响应
    ci_env = os.getenv('CI', '').lower() == 'true'
    if ci_env:
        server_healthy = True  # CI环境中假设服务器健康
    else:
        server_healthy = api_client.health_check()
    
    return jsonify({
        "status": "ok",
        "local": True,
        "server": server_healthy,
        "server_url": api_client.server_url,
        "timestamp": datetime.now().isoformat(),
        "ci_mode": ci_env
    })

@app.route("/api/jobs", methods=["GET"])
def list_jobs():
    """列出本地缓存的任务"""
    try:
        jobs = LocalJob.query.order_by(LocalJob.created_at.desc()).limit(50).all()
        result = []
        for job in jobs:
            result.append({
                'id': job.id,
                'remote_job_id': job.remote_job_id,
                'type': job.type,
                'status': job.status,
                'prompt_id': job.prompt_id,
                'created_at': job.created_at.isoformat()
            })
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 静态文件代理（如果本地没有）
@app.route("/static/<path:filename>")
def static_proxy(filename):
    """静态文件代理"""
    try:
        # 首先尝试本地文件
        return send_from_directory(app.static_folder, filename)
    except:
        try:
            # 如果本地没有，代理到远程服务器
            response = api_client.proxy_request('GET', f'/static/{filename}', timeout=30, stream=True)
            
            if response.status_code == 200:
                content_type = response.headers.get('Content-Type', 'application/octet-stream')
                return Response(response.content, mimetype=content_type)
            else:
                return Response("File not found", status=404)
        except Exception as e:
            return Response(f"Error: {str(e)}", status=500)

# 添加favicon支持
@app.route("/favicon.ico")
def favicon():
    """Favicon"""
    try:
        return send_from_directory(app.static_folder, 'favicon.ico')
    except:
        # 返回一个简单的透明图标
        return Response(
            base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='),
            mimetype='image/png'
        )

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

def main():
    """主函数"""
    print("🚀 启动BaiduCBIT本地版本 v2.0...")
    print(f"📡 服务器地址: {api_client.server_url}")
    
    # 创建数据库表
    with app.app_context():
        try:
            db.create_all()
            db_type = "内存数据库" if app.config['SQLALCHEMY_DATABASE_URI'] == 'sqlite:///:memory:' else "本地数据库"
            print(f"✓ {db_type}已初始化")
        except Exception as e:
            print(f"⚠️  数据库初始化失败: {e}")
            raise
    
    # 检查服务器连接（CI环境中跳过以加快启动）
    ci_env = os.getenv('CI', '').lower() == 'true'
    if not ci_env:
        if api_client.health_check():
            print("✅ 服务器连接正常")
        else:
            print("⚠️  警告: 无法连接到服务器，请检查网络和服务器状态")
            print("   部分功能可能无法正常使用")
    else:
        print("🔧 CI环境检测到，跳过远程服务器连接检查")
    
    # 创建必要目录
    Path('./downloads').mkdir(exist_ok=True)
    
    # 启动应用
    host = os.getenv('HOST', '127.0.0.1')
    port = int(os.getenv('PORT', '5000'))
    debug = os.getenv('DEBUG', 'True').lower() == 'true'
    
    print(f"🌐 本地访问地址: http://{host}:{port}")
    print("📱 界面与服务器端完全一致")
    print("🔄 所有API请求将代理到远程服务器")
    print("按 Ctrl+C 停止服务")
    
    app.run(host=host, port=port, debug=debug)

if __name__ == '__main__':
    main()
