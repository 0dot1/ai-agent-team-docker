# AI Agent Team - Quick Start

# 1. Clone and enter directory
cd ~/ai-team-docker

# 2. Copy environment template
cp .env.example .env

# 3. Edit with your API keys
nano .env

# 4. Start all services
docker compose up -d

# 5. Check status
docker compose ps

# 6. View logs
docker compose logs -f

# Done! Access OpenClaw at http://your-server-ip:18789