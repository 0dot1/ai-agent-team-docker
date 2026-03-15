# i7 Team Docker 部署指南（安全版）

## 🚀 快速部署步骤

### 1. 准备环境

```bash
# SSH 连接到 Ubuntu 服务器
ssh root@YOUR_SERVER_IP

# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Docker Compose
apt-get update && apt-get install -y docker-compose-plugin
```

### 2. 创建项目目录

```bash
mkdir -p /opt/i7-docker
cd /opt/i7-docker
```

### 3. 创建配置文件

**创建 .env 文件（自行填入）：**

```bash
nano .env
```

**.env 内容模板：**
```env
# Claude API Key（从 Anthropic 控制台获取）
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxx

# Telegram Bot Tokens（从 @BotFather 获取）
TELEGRAM_BOT_TOKEN_PM=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_UI=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_FRONTEND=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_BACKEND=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_APP=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_SECURITY=xxxxxxxxxx:xxxxxxxxxxxxxxxx
TELEGRAM_BOT_TOKEN_OPS=xxxxxxxxxx:xxxxxxxxxxxxxxxx

# Claude 模型选择
CLAUDE_MODEL=claude-3-haiku-20240307

# 监控密码（可选）
GRAFANA_PASSWORD=your_password
```

### 4. 创建 docker-compose.yml

```bash
nano docker-compose.yml
```

（内容参考完整版 docker-compose.yml）

### 5. 创建 Agent 代码

```bash
mkdir -p agents
nano agents/Dockerfile
nano agents/package.json
nano agents/agent.js
```

### 6. 创建 OpenClaw Gateway（可选）

```bash
mkdir -p openclaw-gateway
nano openclaw-gateway/Dockerfile
nano openclaw-gateway/package.json
nano openclaw-gateway/gateway.js
```

### 7. 部署启动

```bash
# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

---

## 📁 文件结构

```
/opt/i7-docker/
├── docker-compose.yml      # 主配置
├── .env                    # 环境变量（自己创建）
├── agents/
│   ├── Dockerfile
│   ├── package.json
│   └── agent.js
├── openclaw-gateway/       # 可选
│   ├── Dockerfile
│   ├── package.json
│   └── gateway.js
└── logs/                   # 日志目录
```

---

## 🔧 常用命令

```bash
# 查看所有服务状态
docker-compose ps

# 查看实时日志
docker-compose logs -f

# 重启所有服务
docker-compose restart

# 停止服务
docker-compose down

# 更新镜像
docker-compose pull && docker-compose up -d

# 进入容器调试
docker-compose exec agent-pm sh
```

---

## 🧪 测试

**Telegram 测试：**
1. 打开 Telegram
2. 搜索并添加 Bot（如 @i7_pm_bot）
3. 发送消息测试

**OpenClaw API 测试：**
```bash
curl http://localhost:18789/health
```

---

## 🔒 安全建议

1. **保护 .env 文件**
   ```bash
   chmod 600 .env
   ```

2. **防火墙设置**
   ```bash
   ufw allow 22,80,443,18789/tcp
   ufw enable
   ```

3. **定期备份**
   ```bash
   tar czvf i7-backup-$(date +%Y%m%d).tar.gz /opt/i7-docker
   ```

4. **不要在代码中硬编码敏感信息**，全部使用环境变量

---

## ❓ 故障排查

**问题1: 服务无法启动**
```bash
docker-compose logs
# 检查错误信息
```

**问题2: API 调用失败**
- 检查 .env 中的 API Key 是否正确
- 检查 Claude 账户余额

**问题3: Telegram Bot 不回复**
- 检查 Bot Token 是否正确
- 检查网络连接

---

## 📞 支持

- Claude 控制台: https://console.anthropic.com/
- Telegram BotFather: https://t.me/BotFather