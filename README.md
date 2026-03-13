# Ubuntu 24.04 LTS + Docker 部署指南

## 📦 部署包结构

```
ai-team-docker/
├── docker-compose.yml          # 主配置文件
├── install-ubuntu24.sh         # 一键安装脚本
├── .env.example               # 环境变量模板
├── start.sh                   # 启动脚本
├── stop.sh                    # 停止脚本
├── openclaw/
│   └── Dockerfile
├── coordinator/
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── agents/
│   ├── pm/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   ├── ui/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   ├── app/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   ├── security/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── agent.js
│   └── ops/
│       ├── Dockerfile
│       ├── package.json
│       └── agent.js
├── nginx/
│   └── nginx.conf
└── monitoring/
    └── prometheus.yml
```

## 🚀 快速部署步骤

### 1. 准备Ubuntu 24服务器

要求：
- Ubuntu 24.04 LTS
- 最低配置：4核CPU / 8GB内存 / 50GB硬盘
- 推荐配置：8核CPU / 16GB内存 / 100GB硬盘
- 开放端口：22(SSH), 80(HTTP), 443(HTTPS), 18789(OpenClaw)

### 2. 下载部署包

```bash
# 在你的Ubuntu服务器上执行
cd ~
git clone https://github.com/yourusername/ai-team-docker.git
# 或者上传部署包后解压
cd ai-team-docker
```

### 3. 运行安装脚本

```bash
chmod +x install-ubuntu24.sh
sudo ./install-ubuntu24.sh
```

脚本会自动：
- ✅ 更新系统
- ✅ 安装Docker和Docker Compose
- ✅ 配置防火墙
- ✅ 创建目录结构

### 4. 配置环境变量

```bash
cp .env.example .env
nano .env
```

填写以下信息：

```env
# AI模型API密钥
ANTHROPIC_API_KEY=sk-ant-api03-xxx
OPENAI_API_KEY=sk-xxx

# Telegram Bot Tokens (从@BotFather获取)
TELEGRAM_BOT_TOKEN_PM=xxx:xxx
TELEGRAM_BOT_TOKEN_UI=xxx:xxx
TELEGRAM_BOT_TOKEN_FRONTEND=xxx:xxx
TELEGRAM_BOT_TOKEN_BACKEND=xxx:xxx
TELEGRAM_BOT_TOKEN_APP=xxx:xxx
TELEGRAM_BOT_TOKEN_SECURITY=xxx:xxx
TELEGRAM_BOT_TOKEN_OPS=xxx:xxx
```

### 5. 启动服务

```bash
./start.sh
```

## 📱 Telegram Bot 设置

### 获取Bot Token

1. 在Telegram中搜索 @BotFather
2. 发送 `/newbot`
3. 输入Bot名称（如：YourProject PM）
4. 输入Bot用户名（如：yourproject_pm_bot）
5. 复制Token（格式：`123456789:ABCdefGHIjklMNOpqrSTUvwxyz`）

### 创建群组并添加Bots

1. 在Telegram创建新群组
2. 添加所有7个Bot
3. 给Bot管理员权限（可选，用于读取消息）

### 测试

在群组中发送：
```
@yourproject_pm_bot 我们需要开发一个电商App
```

## 🔧 管理命令

```bash
# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f
docker compose logs -f agent-pm  # 只看PM日志

# 重启服务
docker compose restart

# 更新到最新版本
./update.sh

# 停止服务
./stop.sh

# 进入容器调试
docker exec -it agent-pm sh
```

## 🌐 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| OpenClaw | http://服务器IP:18789 | 主网关 |
| Grafana | http://服务器IP:3000 | 监控面板 |
| Prometheus | http://服务器IP:9090 | 指标收集 |

## 🔒 安全配置

### 启用SSL（推荐）

```bash
# 安装certbot
sudo apt install certbot python3-certbot-nginx

# 申请证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo systemctl enable certbot.timer
```

### 防火墙设置

```bash
# 查看防火墙状态
sudo ufw status

# 默认拒绝入站
sudo ufw default deny incoming

# 允许SSH
sudo ufw allow 22/tcp

# 允许HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 启用防火墙
sudo ufw enable
```

## 📊 监控

### Grafana登录

- 地址：http://服务器IP:3000
- 默认账号：admin
- 密码：admin（首次登录会提示修改）

### 查看容器资源使用

```bash
docker stats
```

## 🐛 故障排查

### 问题1：容器无法启动

```bash
# 查看详细错误
docker compose logs agent-pm

# 检查环境变量
cat .env

# 重启单个服务
docker compose restart agent-pm
```

### 问题2：API Key无效

```bash
# 检查Key是否设置
docker compose exec agent-pm env | grep API

# 更新.env后重启
docker compose down
docker compose up -d
```

### 问题3：Telegram Bot不响应

1. 检查Bot Token是否正确
2. 确认Bot已添加到群组
3. 检查Bot是否有发送消息权限
4. 查看日志：`docker compose logs coordinator`

### 问题4：内存不足

```bash
# 查看内存使用
free -h

# 添加Swap（如果物理内存不足8GB）
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 💰 成本估算

### 服务器成本

| 配置 | 月费用 | 推荐用途 |
|------|--------|----------|
| 4核8G | ¥100-200 | 测试环境 |
| 8核16G | ¥300-500 | 生产环境（推荐） |
| 16核32G | ¥800-1200 | 大型团队 |

### API成本

| 模型 | 月费用 | 说明 |
|------|--------|------|
| Claude 3.5 Sonnet | $20-50 | 主力开发 |
| GPT-4o | $20-30 | 安全/运营 |
| 合计 | ¥300-600 | 正常使用 |

## 📞 支持

- OpenClaw文档：https://docs.openclaw.ai
- Docker文档：https://docs.docker.com
- 问题反馈：在GitHub提交Issue

---

## 🎉 部署完成！

现在你的AI Agent团队已经在Ubuntu 24上运行了。在Telegram群组中@机器人开始协作吧！