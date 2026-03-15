#!/bin/bash
# i7 Team - Docker + OpenClaw 一键部署脚本
# Ubuntu 24.04 LTS

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🚀 i7 Team Docker + OpenClaw 部署脚本                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==========================================
# 检查 Docker
# ==========================================
echo ""
echo "📋 检查 Docker 环境..."

if ! command -v docker &> /dev/null; then
    log_info "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    log_success "Docker 安装完成"
else
    log_success "Docker: $(docker --version)"
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_info "安装 Docker Compose..."
    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
fi
log_success "Docker Compose 可用"

# ==========================================
# 项目目录
# ==========================================
PROJECT_DIR="/opt/i7-docker"
sudo mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

log_info "项目目录: $PROJECT_DIR"

# ==========================================
# 检查配置文件
# ==========================================
echo ""
echo "📄 检查配置文件..."

if [ ! -f ".env" ]; then
    log_error ".env 文件不存在!"
    echo ""
    echo "请创建 .env 文件:"
    echo "  sudo nano $PROJECT_DIR/.env"
    echo ""
    echo "参考 .env.example 填写:"
    echo "  - ANTHROPIC_API_KEY (Claude API Key)"
    echo "  - Telegram Bot Tokens (7个)"
    echo ""
    exit 1
fi

# 检查 Key 是否已配置
if grep -q "你的ClaudeKey" .env || grep -q "your-key" .env; then
    log_error ".env 中的 API Key 未配置!"
    echo ""
    echo "请编辑 .env 文件填入真实的 API Key:"
    echo "  sudo nano $PROJECT_DIR/.env"
    echo ""
    exit 1
fi

log_success ".env 配置正确"

# ==========================================
# 创建目录结构
# ==========================================
echo ""
echo "📁 创建目录结构..."

sudo mkdir -p logs/{gateway,pm,ui,frontend,backend,app,security,ops}

# ==========================================
# 构建并启动
# ==========================================
echo ""
echo "🐳 构建 Docker 镜像..."

sudo docker-compose build

log_success "镜像构建完成"

echo ""
echo "🚀 启动 i7 Team..."

sudo docker-compose up -d

echo ""
echo "⏳ 等待服务启动 (15秒)..."
sleep 15

echo ""
echo "📊 服务状态:"
sudo docker-compose ps

# ==========================================
# 测试 OpenClaw Gateway
# ==========================================
echo ""
echo "🧪 测试 OpenClaw Gateway..."

if curl -s http://localhost:18789/health > /dev/null; then
    log_success "OpenClaw Gateway 运行正常!"
    curl -s http://localhost:18789/health | jq . 2>/dev/null || curl -s http://localhost:18789/health
else
    log_warn "OpenClaw Gateway 可能还未就绪，稍后检查..."
fi

echo ""
echo "📋 查看日志:"
sudo docker-compose logs --tail=10

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ 部署完成!                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 OpenClaw Gateway: http://$(curl -s ifconfig.me):18789"
echo "   API 文档: http://$(curl -s ifconfig.me):18789/health"
echo ""
echo "📱 Telegram Bot:"
echo "  @i7_pm_bot, @i7_ui_bot, @i7_frontend_bot"
echo "  @i7_backend_bot, @i7_app_bot, @i7_sec_bot, @i7_opt_bot"
echo ""
echo "🛠️  管理命令:"
echo "  cd $PROJECT_DIR"
echo "  sudo docker-compose logs -f              # 查看日志"
echo "  sudo docker-compose ps                   # 查看状态"
echo "  sudo docker-compose restart              # 重启服务"
echo "  sudo docker-compose down                 # 停止服务"
echo "  sudo docker-compose pull && sudo docker-compose up -d  # 更新"
echo ""
echo "💡 OpenClaw API 示例:"
echo "  curl http://localhost:18789/health"
echo "  curl http://localhost:18789/api/v1/agents"
echo ""
echo "🎯 测试: 在 Telegram 中给 @i7_pm_bot 发送消息!"
echo ""