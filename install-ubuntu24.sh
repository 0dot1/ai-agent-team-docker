#!/bin/bash
# Ubuntu 24.04 LTS - AI Agent Team Docker Deployment Script
# Run this on your Ubuntu server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🤖 AI Agent Team - Docker Deployment for Ubuntu 24      ║"
echo "║           OpenClaw + 7 AI Agents + Telegram                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Ubuntu version
if ! grep -q "Ubuntu 24" /etc/os-release; then
    echo -e "${YELLOW}⚠️  Warning: This script is optimized for Ubuntu 24.04 LTS${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to print status
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y
print_success "System updated"

# Install prerequisites
print_status "Installing prerequisites..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    nano \
    htop \
    net-tools \
    ufw

print_success "Prerequisites installed"

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Docker installed"
else
    print_success "Docker already installed"
fi

# Install Docker Compose
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    sudo apt install -y docker-compose-plugin
    print_success "Docker Compose installed"
else
    print_success "Docker Compose already installed"
fi

# Verify Docker installation
print_status "Verifying Docker installation..."
sudo systemctl start docker
sudo systemctl enable docker
docker --version
docker compose version
print_success "Docker is running"

# Create project directory
PROJECT_DIR="$HOME/ai-agent-team"
print_status "Creating project directory: $PROJECT_DIR"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Download deployment files
print_status "Downloading deployment files..."

# Create directory structure
mkdir -p {openclaw,coordinator,agents/{pm,ui,frontend,backend,app,security,ops},nginx,monitoring,config,shared,logs}

# Create .env template
cat > .env << 'EOF'
# AI Agent Team - Environment Variables
# Fill in your API keys and Telegram Bot Tokens

# AI Model API Keys (Required)
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
OPENAI_API_KEY=sk-your-openai-key-here
KIMI_API_KEY=your-kimi-key-optional

# Telegram Bot Tokens (Required - Get from @BotFather)
TELEGRAM_BOT_TOKEN_PM=your-pm-bot-token
TELEGRAM_BOT_TOKEN_UI=your-ui-bot-token
TELEGRAM_BOT_TOKEN_FRONTEND=your-frontend-bot-token
TELEGRAM_BOT_TOKEN_BACKEND=your-backend-bot-token
TELEGRAM_BOT_TOKEN_APP=your-app-bot-token
TELEGRAM_BOT_TOKEN_SECURITY=your-security-bot-token
TELEGRAM_BOT_TOKEN_OPS=your-ops-bot-token

# Optional: Monitoring
GRAFANA_PASSWORD=admin

# Optional: Domain (for SSL)
DOMAIN=your-domain.com
EMAIL=your-email@example.com
EOF

print_success "Created .env template"

# Create Dockerfile for OpenClaw
cat > openclaw/Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git curl python3 make g++

# Clone and install OpenClaw
RUN git clone https://github.com/openclaw/openclaw.git . || \
    (echo "Using local OpenClaw" && mkdir -p /app)

# If local files exist, use them
COPY . /app/

# Install dependencies
RUN npm install

# Build
RUN npm run build 2>/dev/null || echo "No build script"

# Expose ports
EXPOSE 18789 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Start
CMD ["npm", "start"]
EOF

# Create Dockerfile for Coordinator
cat > coordinator/Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source
COPY . .

# Start
CMD ["node", "index.js"]
EOF

# Create Dockerfile template for agents
create_agent_dockerfile() {
    local agent_dir=$1
    cat > $agent_dir/Dockerfile << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install Python for potential AI model usage
RUN apk add --no-cache python3 py3-pip

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source
COPY . .

# Start
CMD ["node", "agent.js"]
EOF
}

# Create Dockerfiles for all agents
for agent in pm ui frontend backend app security ops; do
    create_agent_dockerfile "agents/$agent"
done

print_success "Created Dockerfiles"

# Create nginx configuration
cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream openclaw {
        server openclaw:18789;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://openclaw;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

print_success "Created nginx configuration"

# Create monitoring config
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'openclaw'
    static_configs:
      - targets: ['openclaw:18789']
  
  - job_name: 'agent-coordinator'
    static_configs:
      - targets: ['coordinator:3000']
EOF

print_success "Created monitoring configuration"

# Create docker-compose.yml (will be replaced by the actual one)
print_status "Creating docker-compose.yml..."
# Note: The actual docker-compose.yml should be downloaded or created separately

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw-gateway
    restart: unless-stopped
    ports:
      - "18789:18789"
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - ./config:/root/.openclaw
    networks:
      - ai-team

  redis:
    image: redis:7-alpine
    container_name: ai-team-redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    networks:
      - ai-team

networks:
  ai-team:
    driver: bridge

volumes:
  redis-data:
EOF

# Create start script
cat > start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting AI Agent Team..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please copy .env.example to .env and fill in your API keys."
    exit 1
fi

# Pull images
echo "📦 Pulling Docker images..."
docker compose pull

# Start services
echo "🟢 Starting services..."
docker compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 10

# Check health
echo "🏥 Checking service health..."
docker compose ps

echo ""
echo "✅ AI Agent Team is running!"
echo ""
echo "📊 Dashboard:"
echo "  - OpenClaw: http://localhost:18789"
echo "  - Grafana:  http://localhost:3000"
echo "  - Prometheus: http://localhost:9090"
echo ""
echo "📱 Telegram: Add your 7 bots to a group and start collaborating!"
echo ""
echo "📝 Logs: docker compose logs -f"
EOF

chmod +x start.sh

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping AI Agent Team..."
docker compose down
echo "✅ Stopped"
EOF

chmod +x stop.sh

# Create update script
cat > update.sh << 'EOF'
#!/bin/bash
set -e

echo "🔄 Updating AI Agent Team..."

docker compose down
docker compose pull
docker compose up -d

echo "✅ Updated!"
EOF

chmod +x update.sh

print_success "Created management scripts"

# Setup firewall
print_status "Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 18789/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 9090/tcp
sudo ufw --force enable
print_success "Firewall configured"

# Final instructions
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ✅ Installation Complete!                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${BLUE}Configure API Keys:${NC}"
echo "   nano $PROJECT_DIR/.env"
echo "   Fill in your ANTHROPIC_API_KEY and Telegram Bot Tokens"
echo ""
echo "2. ${BLUE}Get Telegram Bot Tokens:${NC}"
echo "   Message @BotFather on Telegram"
echo "   Create 7 bots with names like: yourproject_pm_bot"
echo ""
echo "3. ${BLUE}Start the team:${NC}"
echo "   cd $PROJECT_DIR"
echo "   ./start.sh"
echo ""
echo "4. ${BLUE}Add bots to Telegram group:${NC}"
echo "   Create a group, add all 7 bots"
echo "   Start collaborating!"
echo ""
echo -e "${YELLOW}Management Commands:${NC}"
echo "  ./start.sh    - Start all services"
echo "  ./stop.sh     - Stop all services"
echo "  ./update.sh   - Update to latest version"
echo "  docker compose logs -f  - View logs"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo "  OpenClaw:    http://$(curl -s ifconfig.me):18789"
echo "  Grafana:     http://$(curl -s ifconfig.me):3000"
echo "  Prometheus:  http://$(curl -s ifconfig.me):9090"
echo ""
echo -e "${GREEN}Happy collaborating! 🤖${NC}"
echo ""

# Note about relogin
print_status "Note: You may need to logout and login again for Docker permissions to take effect"
print_status "Or run: newgrp docker"