#!/bin/bash
# i7 Team - Docker 一键部署脚本
# Ubuntu 24.04 LTS

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🚀 i7 Team Docker 部署脚本                              ║"
echo "║        OpenClaw + Claude + Telegram AI 团队                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==========================================
# 1. 检查系统环境
# ==========================================
echo ""
echo "📋 Step 1/5: 检查系统环境..."

if ! grep -q "Ubuntu 24" /etc/os-release 2>/dev/null; then
    log_warn "非 Ubuntu 24.04 系统，但继续部署..."
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
    log_info "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    log_success "Docker 安装完成"
else
    log_success "Docker 已安装: $(docker --version)"
fi

# 检查 Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_info "安装 Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

log_success "Docker Compose 可用"

# ==========================================
# 2. 创建项目目录
# ==========================================
echo ""
echo "📁 Step 2/5: 创建项目目录..."

PROJECT_DIR="/opt/i7-docker"
sudo mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

sudo mkdir -p {logs,config,nginx,monitoring}
sudo mkdir -p logs/{pm,ui,frontend,backend,app,security,ops}

log_success "项目目录创建完成: $PROJECT_DIR"

# ==========================================
# 3. 下载配置文件
# ==========================================
echo ""
echo "📥 Step 3/5: 下载配置文件..."

# 创建 docker-compose.yml
log_info "创建 docker-compose.yml..."
# 这里应该下载或使用本地文件
# 假设文件已在当前目录

# 创建 .env 文件
if [ ! -f .env ]; then
    log_info "创建 .env 配置文件..."
    cat > .env <> EOF
# i7 Team 环境配置
ANTHROPIC_API_KEY=sk-ant-api03-你的ClaudeKey

TELEGRAM_BOT_TOKEN_PM=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_UI=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_FRONTEND=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_BACKEND=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_APP=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_SECURITY=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_OPS=xxxxxxxxxx:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

CLAUDE_MODEL=claude-3-haiku-20240307
GRAFANA_PASSWORD=admin
EOF
    log_warn "请编辑 .env 文件，填入你的 Claude API Key"
fi

# ==========================================
# 4. 构建和启动
# ==========================================
echo ""
echo "🐳 Step 4/5: 构建 Docker 镜像..."

# 检查 .env 是否已配置
if grep -q "你的ClaudeKey" .env; then
    log_error "请先在 .env 文件中填入真实的 Claude API Key!"
    echo ""
    echo "编辑命令:"
    echo "  sudo nano $PROJECT_DIR/.env"
    echo ""
    exit 1
fi

# 构建镜像
log_info "构建 Agent 镜像..."
sudo docker-compose build

log_success "镜像构建完成"

# ==========================================
# 5. 启动服务
# ==========================================
echo ""
echo "🚀 Step 5/5: 启动 i7 Team..."

sudo docker-compose up -d

echo ""
echo "⏳ 等待服务启动..."
sleep 10

echo ""
echo "📊 服务状态:"
sudo docker-compose ps

echo ""
echo "📋 查看日志:"
sudo docker-compose logs --tail=20

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ 部署完成!                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📱 Telegram Bot 列表:"
echo "  @i7_pm_bot       - 项目经理 i10"
echo "  @i7_ui_bot       - 设计师 i9"
echo "  @i7_frontend_bot - 大前端 i8"
echo "  @i7_backend_bot  - 全栈大佬 i6"
echo "  @i7_app_bot      - App小研 i5"
echo "  @i7_sec_bot      - 安全大哥 i3"
echo "  @i7_opt_bot      - 运营大师 i1"
echo ""
echo "🌐 访问地址:"
echo "  OpenClaw: http://$(curl -s ifconfig.me):18789"
echo "  Grafana:  http://$(curl -s ifconfig.me):3000"
echo ""
echo "🛠️  管理命令:"
echo "  cd $PROJECT_DIR"
echo "  sudo docker-compose logs -f        # 查看日志"
echo "  sudo docker-compose restart        # 重启服务"
echo "  sudo docker-compose down           # 停止服务"
echo "  sudo docker-compose pull && sudo docker-compose up -d  # 更新"
echo ""
echo "💡 测试: 在 Telegram 中给 @i7_pm_bot 发送消息!"
echo ""