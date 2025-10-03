# BaiduCBIT - 基于ComfyUI的企业级AI图像生成平台

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Flask](https://img.shields.io/badge/Flask-3.0+-green.svg)](https://flask.palletsprojects.com/)
[![ComfyUI](https://img.shields.io/badge/ComfyUI-Latest-orange.svg)](https://github.com/comfyanonymous/ComfyUI)
[![Flux](https://img.shields.io/badge/Flux-1.0%20Dev-purple.svg)](https://huggingface.co/black-forest-labs/FLUX.1-dev)

## 🎬 最新演示

### 界面展示录屏 (2025-10-02)
> **最新优化界面演示** - 展示了全新的用户友好界面设计和一键生成功能

📹 **演示视频**: [`showcase_instruction.mov`](https://cbit.cuhk.edu.cn/files/showcase_instruction.mov)

> 注意：由于文件大小限制，录屏文件未包含在Git仓库中。如需查看演示，请联系开发者获取。

**主要特性演示**:
- 🚀 **一键生成**: 简化的操作流程，输入提示词即可快速生成
- 🎨 **精选模板**: 人像摄影、生活场景、艺术风格等专业预设
- ⚙️ **智能设置**: 可折叠的高级参数配置
- 🌟 **现代界面**: 玻璃拟态设计，响应式布局
- 🔄 **实时反馈**: 生成进度和状态实时显示

## 致谢

感谢**百度深圳广告投放部门**对本项目的大力支持与贡献！他们的专业指导和资源投入为项目的成功实施提供了重要保障。

Special thanks to **Baidu Shenzhen Advertising Department** for their tremendous support and contribution to this project! Their professional guidance and resource investment have provided crucial support for the successful implementation of this project.

---

## 项目概述

BaiduCBIT是一个基于ComfyUI的企业级AI图像生成平台，专注于真人级别的高质量图像生成。该平台采用先进的Flux模型架构，结合多种AI增强技术，实现了从文本描述到真实感图像的端到端生成流程。

## 核心技术架构

### 1. 深度学习模型栈

#### 主模型架构
- **Flux 1.0 Dev Model**: 基于Diffusion Transformer架构的最新生成模型
  - 模型精度: FP8_E4M3FN量化，优化内存使用
  - 参数规模: 12B参数，支持高分辨率图像生成
  - 潜在空间: 8x压缩比的VAE编码器

#### 文本编码器
- **Dual-CLIP Architecture**: 
  - CLIP-L: 处理视觉-语言理解
  - T5-XXL FP16: 增强文本语义理解能力
  - 支持多语言输入和语义对齐

#### LoRA微调模块
- **手部修复LoRA**: 专门优化人体手部细节生成
- **反模糊LoRA**: 提升图像锐度和细节保真度
- **真实感增强LoRA**: 优化人像真实感和皮肤质感
- **Flux增强LoRA**: 模型性能整体提升

### 2. 高级采样算法

#### 双阶段采样策略
```
第一阶段: 高噪声去噪 (Sigma Split: 0.7)
├── 噪声注入强度: 0.85
├── 采样器: Euler Ancestral + Advanced Lying Sigma
└── 步数: 30步 (70%阶段)

第二阶段: 精细化处理 (Sigma Split: 0.3)
├── 禁用噪声注入
├── 潜在空间插值: 0.35比例
└── 细节增强采样
```

#### 自适应引导机制
- **Flux Guidance**: 动态调整生成遵循度 (范围: 2.0-5.0)
- **ControlNet Integration**: 支持结构化控制生成
- **Negative Prompting**: 智能负面提示词过滤

### 3. 图像后处理管线

#### 多层次增强流程
```
原始输出 → 锐化处理 → 胶片颗粒 → CA锐化 → 最终输出
    ↓           ↓         ↓        ↓
  VAE解码    ImageSharpen  FilmGrain  CASharp
```

- **自适应锐化**: 基于内容的智能锐化算法
- **胶片颗粒模拟**: 增加真实摄影质感
- **色差校正**: 消除色彩偏移，提升色彩准确度

### 4. 分布式架构设计

#### 生产环境架构
```
Web前端 → Flask应用 → ComfyUI引擎 → GPU集群
    ↓         ↓          ↓           ↓
  用户界面   API网关    工作流引擎   模型推理
```

#### 本地开发架构
```
开发环境 → 推理服务 → 远程ComfyUI → 云端GPU
    ↓         ↓          ↓          ↓
  本地调试   服务代理    API转发    模型计算
```

## 技术特性

### 真人级图像生成能力

#### 1. 高保真人像生成
- **皮肤质感**: 基于物理的皮肤渲染，支持不同肤色和年龄
- **面部细节**: 精确的五官比例和表情捕捉
- **发丝细节**: 单根发丝级别的细节还原
- **光影效果**: 真实的光照模拟和阴影投射

#### 2. 身体结构优化
- **手部修复**: 专门的LoRA模型解决手部畸变问题
- **身体比例**: 符合人体工程学的比例控制
- **服装细节**: 面料质感和褶皱的真实模拟
- **姿态自然**: 自然的人体姿态和动作表现

#### 3. 场景融合技术
- **环境光照**: 与场景光照的无缝融合
- **景深效果**: 专业摄影级别的景深控制
- **材质反射**: 真实的材质光学特性
- **大气透视**: 距离感和空间层次的准确表现

### 多语言智能翻译

#### 翻译引擎集成
- **Bing Translator API**: 支持100+语言的高质量翻译
- **语义增强**: 自动添加摄影和质量相关的专业术语
- **上下文理解**: 基于场景的智能词汇选择
- **风格适配**: 根据生成风格调整提示词表达

#### 提示词优化
```python
原始输入: "一位美丽的中国女性在咖啡馆读书"
↓ 翻译处理
智能输出: "A beautiful Chinese woman reading in a coffee shop, 
          high quality, detailed, realistic, professional photography, 
          sharp focus, natural lighting, lifestyle photo"
```

### ControlNet精确控制

#### 支持的控制类型
- **Tile Control**: 基于参考图像的结构控制
- **Depth Control**: 深度图引导的空间布局
- **Pose Control**: 人体姿态的精确控制
- **Edge Control**: 边缘检测引导的轮廓生成

#### 预处理管线
- **AIO Preprocessor**: 自动选择最适合的预处理器
- **Union ControlNet**: 多种控制类型的统一处理
- **强度调节**: 0.0-1.0范围的精细控制强度调节

## 部署架构优势

### 生产环境部署

#### 优势特性
1. **高性能**: 直连ComfyUI，减少网络延迟
2. **稳定性**: 本地化部署，避免外部依赖
3. **安全性**: 数据不出本地，保护用户隐私
4. **可扩展**: 支持GPU集群和负载均衡
5. **成本效益**: 一次部署，长期使用

#### 技术栈
```
前端: Flask + Jinja2 + JavaScript
后端: Python 3.12 + SQLAlchemy + MySQL
AI引擎: ComfyUI + PyTorch + CUDA 12.4
部署: Gunicorn + Nginx + Docker (可选)
```

### 本地开发环境

#### 优势特性
1. **快速迭代**: 本地开发，实时调试
2. **资源共享**: 通过推理服务共享GPU资源
3. **环境隔离**: 开发环境与生产环境分离
4. **成本控制**: 按需使用云端GPU资源
5. **团队协作**: 多人共享同一推理服务

#### 架构特点
```
本地Flask应用 ←→ 推理服务代理 ←→ 远程ComfyUI集群
      ↓                ↓                ↓
   界面开发         API转发           模型计算
   逻辑调试         负载均衡           资源管理
   快速测试         错误处理           结果缓存
```

## 性能指标

### 图像生成性能
- **分辨率**: 支持896x1392到2048x2048
- **生成时间**: 30步采样约15-30秒 (RTX 4090)
- **内存占用**: 8GB VRAM (FP8量化)
- **批处理**: 支持批量生成和队列管理

### 系统性能
- **并发处理**: 支持多用户同时生成
- **队列管理**: 智能任务调度和优先级控制
- **缓存机制**: 模型缓存和结果缓存
- **监控告警**: 实时性能监控和异常告警

## 工作流配置

### 核心工作流文件
- `fluxfinalV1.json`: 完整的真人生图工作流
- `flux819translate.json`: 带翻译功能的工作流
- `flux820withouttran.json`: 无翻译的优化工作流

### 参数配置
```json
{
  "model": "flux1-dev.safetensors",
  "scheduler": "euler_ancestral",
  "steps": 30,
  "guidance": 3.0,
  "resolution": "896x1392",
  "lora_stack": ["hand_fix", "antiblur", "realistic"],
  "post_processing": ["sharpen", "film_grain", "ca_sharp"]
}
```

## 安装和部署

### 系统要求
- **操作系统**: Linux (Ubuntu 20.04+推荐)
- **Python**: 3.12+
- **GPU**: NVIDIA RTX 3080+ (8GB+ VRAM)
- **CUDA**: 12.4+
- **内存**: 16GB+ RAM
- **存储**: 100GB+ 可用空间

### 快速部署
```bash
# 1. 克隆项目
git clone <repository-url>
cd baiducbit

# 2. 安装依赖
pip install -r requirements.txt

# 3. 初始化配置
cp env.example .env
# 编辑.env文件配置数据库和服务地址

# 4. 启动服务
python run.py
```

### 生产部署
```bash
# 使用Gunicorn启动
gunicorn -c gunicorn_conf.py app:app

# 或使用启动脚本
./scripts/start_baiducbit.sh
```

## API接口

### 核心接口
- `POST /api/generate`: 图像生成
- `GET /api/result`: 获取生成结果
- `POST /api/upload`: 文件上传
- `GET /api/queue`: 队列状态查询

### 示例请求
```python
import requests

# 生成图像
response = requests.post('/api/generate', json={
    'mode': 'translate',
    'original_text': '一位美丽的女性在花园里',
    'width': 896,
    'height': 1392,
    'steps': 30,
    'guidance': 3.0
})

# 获取结果
result = requests.get(f'/api/result?prompt_id={response.json()["prompt_id"]}')
```

## 开发路线图

### 已完成功能
- ✅ Flux模型集成和优化
- ✅ 多语言翻译支持
- ✅ ControlNet控制生成
- ✅ LoRA微调集成
- ✅ 双环境部署架构
- ✅ Web界面和API

### 开发中功能
- 🔄 视频生成集成
- 🔄 批量处理优化
- 🔄 模型热更新
- 🔄 高级缓存机制

### 计划功能
- 📋 多模型支持 (SDXL, SD3.5)
- 📋 实时生成预览
- 📋 用户权限管理
- 📋 API限流和计费
- 📋 分布式GPU集群

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 贡献指南

欢迎提交Issue和Pull Request。请确保：
1. 代码符合PEP 8规范
2. 添加适当的测试用例
3. 更新相关文档
4. 提交前运行完整测试

## 联系方式

- **项目维护者**: BaiduCBIT Team
- **开发者**: [@reneverland](https://github.com/reneverland) - Full-stack Developer · AI Fine-tuning · Multimodal Systems
- **GitHub仓库**: [https://github.com/reneverland/CBIT-AiStudio](https://github.com/reneverland/CBIT-AiStudio)
- **技术支持**: 通过GitHub Issues提交问题和建议
- **文档更新**: 2025年10月

---

*本文档持续更新中，最新版本请查看项目仓库。*

---

# BaiduCBIT - Enterprise-Level AI Image Generation Platform Based on ComfyUI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Flask](https://img.shields.io/badge/Flask-3.0+-green.svg)](https://flask.palletsprojects.com/)
[![ComfyUI](https://img.shields.io/badge/ComfyUI-Latest-orange.svg)](https://github.com/comfyanonymous/ComfyUI)
[![Flux](https://img.shields.io/badge/Flux-1.0%20Dev-purple.svg)](https://huggingface.co/black-forest-labs/FLUX.1-dev)

## 🎬 Latest Demo

### UI Showcase Recording (2025-10-02)
> **Latest Optimized Interface Demo** - Showcasing the new user-friendly interface design and one-click generation functionality

📹 **Demo Video**: [`showcase_instruction.mov`](https://cbit.cuhk.edu.cn/files/showcase_instruction.mov)

> Note: Due to file size limitations, the demo video is not included in the Git repository. Please contact the developer for access.

**Key Features Demonstrated**:
- 🚀 **One-Click Generation**: Simplified workflow, generate images by simply entering prompts
- 🎨 **Featured Templates**: Professional presets for portrait photography, lifestyle scenes, and artistic styles
- ⚙️ **Smart Settings**: Collapsible advanced parameter configuration
- 🌟 **Modern Interface**: Glassmorphism design with responsive layout
- 🔄 **Real-time Feedback**: Live generation progress and status updates

## Project Overview

BaiduCBIT is an enterprise-level AI image generation platform based on ComfyUI, focusing on photorealistic human image generation. The platform adopts advanced Flux model architecture combined with various AI enhancement technologies to achieve end-to-end generation from text descriptions to realistic images.

## Core Technical Architecture

### 1. Deep Learning Model Stack

#### Main Model Architecture
- **Flux 1.0 Dev Model**: Latest generative model based on Diffusion Transformer architecture
  - Model Precision: FP8_E4M3FN quantization for optimized memory usage
  - Parameter Scale: 12B parameters supporting high-resolution image generation
  - Latent Space: VAE encoder with 8x compression ratio

#### Text Encoders
- **Dual-CLIP Architecture**: 
  - CLIP-L: Handles visual-language understanding
  - T5-XXL FP16: Enhanced text semantic understanding capability
  - Supports multilingual input and semantic alignment

#### LoRA Fine-tuning Modules
- **Hand Repair LoRA**: Specialized optimization for human hand detail generation
- **Anti-blur LoRA**: Improves image sharpness and detail fidelity
- **Realism Enhancement LoRA**: Optimizes portrait realism and skin texture
- **Flux Enhancement LoRA**: Overall model performance improvement

### 2. Advanced Sampling Algorithms

#### Dual-Stage Sampling Strategy
```
Stage 1: High-noise Denoising (Sigma Split: 0.7)
├── Noise Injection Strength: 0.85
├── Sampler: Euler Ancestral + Advanced Lying Sigma
└── Steps: 30 steps (70% stage)

Stage 2: Fine-tuning Processing (Sigma Split: 0.3)
├── Disable Noise Injection
├── Latent Space Interpolation: 0.35 ratio
└── Detail Enhancement Sampling
```

#### Adaptive Guidance Mechanism
- **Flux Guidance**: Dynamic adjustment of generation adherence (Range: 2.0-5.0)
- **ControlNet Integration**: Supports structured control generation
- **Negative Prompting**: Intelligent negative prompt filtering

### 3. Image Post-processing Pipeline

#### Multi-level Enhancement Process
```
Raw Output → Sharpening → Film Grain → CA Sharpening → Final Output
    ↓           ↓         ↓        ↓
  VAE Decode  ImageSharpen  FilmGrain  CASharp
```

- **Adaptive Sharpening**: Content-based intelligent sharpening algorithm
- **Film Grain Simulation**: Adds realistic photographic texture
- **Chromatic Aberration Correction**: Eliminates color shift, improves color accuracy

### 4. Distributed Architecture Design

#### Production Environment Architecture
```
Web Frontend → Flask App → ComfyUI Engine → GPU Cluster
    ↓         ↓          ↓           ↓
  User Interface  API Gateway  Workflow Engine  Model Inference
```

#### Local Development Architecture
```
Dev Environment → Inference Service → Remote ComfyUI → Cloud GPU
    ↓         ↓          ↓          ↓
  Local Debug   Service Proxy    API Forward    Model Computation
```

## Technical Features

### Photorealistic Human Image Generation

#### 1. High-Fidelity Portrait Generation
- **Skin Texture**: Physics-based skin rendering supporting different skin tones and ages
- **Facial Details**: Precise facial proportions and expression capture
- **Hair Details**: Individual hair strand level detail restoration
- **Lighting Effects**: Realistic lighting simulation and shadow casting

#### 2. Body Structure Optimization
- **Hand Repair**: Specialized LoRA model solving hand deformation issues
- **Body Proportions**: Human ergonomics-compliant proportion control
- **Clothing Details**: Realistic fabric texture and wrinkle simulation
- **Natural Poses**: Natural human postures and movement expressions

#### 3. Scene Integration Technology
- **Environmental Lighting**: Seamless integration with scene lighting
- **Depth of Field**: Professional photography-level depth control
- **Material Reflection**: Realistic material optical properties
- **Atmospheric Perspective**: Accurate distance perception and spatial layering

### Multilingual Intelligent Translation

#### Translation Engine Integration
- **Bing Translator API**: High-quality translation supporting 100+ languages
- **Semantic Enhancement**: Automatic addition of photography and quality-related professional terms
- **Context Understanding**: Intelligent vocabulary selection based on scenes
- **Style Adaptation**: Adjusts prompt expression according to generation style

#### Prompt Optimization
```python
Original Input: "一位美丽的中国女性在咖啡馆读书"
↓ Translation Processing
Smart Output: "A beautiful Chinese woman reading in a coffee shop, 
          high quality, detailed, realistic, professional photography, 
          sharp focus, natural lighting, lifestyle photo"
```

### ControlNet Precise Control

#### Supported Control Types
- **Tile Control**: Structure control based on reference images
- **Depth Control**: Spatial layout guided by depth maps
- **Pose Control**: Precise control of human poses
- **Edge Control**: Contour generation guided by edge detection

#### Preprocessing Pipeline
- **AIO Preprocessor**: Automatically selects the most suitable preprocessor
- **Union ControlNet**: Unified processing of multiple control types
- **Strength Adjustment**: Fine control strength adjustment in 0.0-1.0 range

## Deployment Architecture Advantages

### Production Environment Deployment

#### Advantage Features
1. **High Performance**: Direct ComfyUI connection, reduced network latency
2. **Stability**: Local deployment, avoiding external dependencies
3. **Security**: Data stays local, protecting user privacy
4. **Scalability**: Supports GPU clusters and load balancing
5. **Cost Effectiveness**: One-time deployment, long-term use

#### Technology Stack
```
Frontend: Flask + Jinja2 + JavaScript
Backend: Python 3.12 + SQLAlchemy + MySQL
AI Engine: ComfyUI + PyTorch + CUDA 12.4
Deployment: Gunicorn + Nginx + Docker (optional)
```

### Local Development Environment

#### Advantage Features
1. **Rapid Iteration**: Local development, real-time debugging
2. **Resource Sharing**: Share GPU resources through inference service
3. **Environment Isolation**: Separation of development and production environments
4. **Cost Control**: On-demand use of cloud GPU resources
5. **Team Collaboration**: Multiple people sharing the same inference service

#### Architecture Features
```
Local Flask App ←→ Inference Service Proxy ←→ Remote ComfyUI Cluster
      ↓                ↓                ↓
   UI Development    API Forwarding    Model Computation
   Logic Debugging   Load Balancing    Resource Management
   Quick Testing     Error Handling    Result Caching
```

## Performance Metrics

### Image Generation Performance
- **Resolution**: Supports 896x1392 to 2048x2048
- **Generation Time**: 30-step sampling approximately 15-30 seconds (RTX 4090)
- **Memory Usage**: 8GB VRAM (FP8 quantization)
- **Batch Processing**: Supports batch generation and queue management

### System Performance
- **Concurrent Processing**: Supports multi-user simultaneous generation
- **Queue Management**: Intelligent task scheduling and priority control
- **Caching Mechanism**: Model caching and result caching
- **Monitoring & Alerting**: Real-time performance monitoring and exception alerting

## Workflow Configuration

### Core Workflow Files
- `fluxfinalV1.json`: Complete photorealistic image generation workflow
- `flux819translate.json`: Workflow with translation functionality
- `flux820withouttran.json`: Optimized workflow without translation

### Parameter Configuration
```json
{
  "model": "flux1-dev.safetensors",
  "scheduler": "euler_ancestral",
  "steps": 30,
  "guidance": 3.0,
  "resolution": "896x1392",
  "lora_stack": ["hand_fix", "antiblur", "realistic"],
  "post_processing": ["sharpen", "film_grain", "ca_sharp"]
}
```

## Installation and Deployment

### System Requirements
- **Operating System**: Linux (Ubuntu 20.04+ recommended)
- **Python**: 3.12+
- **GPU**: NVIDIA RTX 3080+ (8GB+ VRAM)
- **CUDA**: 12.4+
- **Memory**: 16GB+ RAM
- **Storage**: 100GB+ available space

### Quick Deployment
```bash
# 1. Clone project
git clone <repository-url>
cd baiducbit

# 2. Install dependencies
pip install -r requirements.txt

# 3. Initialize configuration
cp env.example .env
# Edit .env file to configure database and service addresses

# 4. Start service
python run.py
```

### Production Deployment
```bash
# Start with Gunicorn
gunicorn -c gunicorn_conf.py app:app

# Or use startup script
./scripts/start_baiducbit.sh
```

## API Interfaces

### Core Interfaces
- `POST /api/generate`: Image generation
- `GET /api/result`: Get generation results
- `POST /api/upload`: File upload
- `GET /api/queue`: Queue status query

### Example Request
```python
import requests

# Generate image
response = requests.post('/api/generate', json={
    'mode': 'translate',
    'original_text': '一位美丽的女性在花园里',
    'width': 896,
    'height': 1392,
    'steps': 30,
    'guidance': 3.0
})

# Get result
result = requests.get(f'/api/result?prompt_id={response.json()["prompt_id"]}')
```

## Development Roadmap

### Completed Features
- ✅ Flux model integration and optimization
- ✅ Multilingual translation support
- ✅ ControlNet control generation
- ✅ LoRA fine-tuning integration
- ✅ Dual-environment deployment architecture
- ✅ Web interface and API

### Features in Development
- 🔄 Video generation integration
- 🔄 Batch processing optimization
- 🔄 Model hot updates
- 🔄 Advanced caching mechanism

### Planned Features
- 📋 Multi-model support (SDXL, SD3.5)
- 📋 Real-time generation preview
- 📋 User permission management
- 📋 API rate limiting and billing
- 📋 Distributed GPU cluster

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing Guidelines

Issues and Pull Requests are welcome. Please ensure:
1. Code follows PEP 8 standards
2. Add appropriate test cases
3. Update relevant documentation
4. Run complete tests before submission

## Contact Information

- **Project Maintainer**: BaiduCBIT Team
- **Developer**: [@reneverland](https://github.com/reneverland) - Full-stack Developer · AI Fine-tuning · Multimodal Systems
- **GitHub Repository**: [https://github.com/reneverland/CBIT-AiStudio](https://github.com/reneverland/CBIT-AiStudio)
- **Technical Support**: Submit issues and suggestions via GitHub Issues
- **Documentation Updated**: October 2025

---

*This document is continuously updated. Please check the project repository for the latest version.*
