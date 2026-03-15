# i7 Team - Docker 完整部署方案

🚀 **OpenClaw + Claude + Telegram AI 团队**

使用 Docker Compose 一键部署 7 个 AI Agent，支持 Claude AI 对话、Redis 状态管理、监控告警。

---

## 📋 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Ubuntu 24.04 Server                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Docker Compose Stack                      │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐             │  │
│  │  │ i10-pm   │ │ i9-ui    │ │ i8-front │  ...        │  │
│  │  │ (Node.js)│ │ (Node.js)│ │ (Node.js)│             │  │
│  │  └──────────┘ └──────────┘ └──────────┘             │  │
│  │       ↓              ↓              ↓                │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │              Redis (共享状态)                  │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │       ↓                                              │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │           Claude API (AI 服务)               │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
│                              ↑                              │
│                     Telegram Bot API                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    用户 (Telegram App)
```

---

## 🛠️ 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Ubuntu 24.04 LTS (推荐) |
| **内存** | 4GB+ (8GB 推荐) |
| **存储** | 20GB+ |
| **网络** | 公网 IP，开放 80/443/18789 端口 |
| **Docker** | 20.10+ |
| **Docker Compose** | 2.0+ |

---

## 🚀 快速开始

### 1. 克隆部署文件

```bash
# 在 Ubuntu 服务器上执行
git clone https://github.com/0dot1/ai-agent-team-docker.git
cd ai-agent-team-docker/i7-docker
```

### 2. 配置环境变量

```bash
# 复制配置文件
cp .env.example .env

# 编辑配置
nano .env
```

**必填项：**
```env
# Claude API Key (必须)
ANTHROPIC_API_KEY=sk-ant-api03-你的ClaudeKey

# Telegram Bot Tokens (必须，已预填)
TELEGRAM_BOT_TOKEN_PM=8626594491:...
TELEGRAM_BOT_TOKEN_UI=8581622849:...
...
```

### 3. 一键部署

```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

或手动部署：
```bash
# 安装 Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# 启动服务
cd /opt/i7-docker
sudo docker-compose up -d --build
```

---

## 📁 目录结构

```
i7-docker/
├── docker-compose.yml      # Docker 编排配置
├── .env                    # 环境变量 (需创建)
├── .env.example            # 环境变量示例
├── deploy.sh               # 一键部署脚本
├── agents/
│   ├── Dockerfile          # Agent 镜像构建
│   ├── package.json        # Node.js 依赖
│   └── agent.js            # 通用 Agent 代码
├── nginx/
│   └── nginx.conf          # Nginx 配置
├── monitoring/
│   └── prometheus.yml      # 监控配置
└── logs/                   # 日志目录
    ├── pm/                 # i10 日志
    ├── ui/                 # i9 日志
    └── ...
```

---

## 🔧 配置说明

### Claude 模型选择

在 `.env` 中设置 `CLAUDE_MODEL`：

| 模型 | 价格 | 推荐用途 |
|------|------|----------|
| `claude-3-opus-20240229` | 最高 | 复杂推理、代码生成 |
| `claude-3-sonnet-20240229` | 中等 | 日常对话、平衡选择 |
| `claude-3-haiku-20240307` | 最低 | 快速回复、成本敏感 |

### 自定义系统提示词

在 `docker-compose.yml` 中修改 `SYSTEM_PROMPT`：

```yaml
environment:
  - SYSTEM_PROMPT=你是自定义角色的AI助手...
```

---

## 📝 常用命令

```bash
cd /opt/i7-docker

# 查看状态
sudo docker-compose ps

# 查看日志
sudo docker-compose logs -f
sudo docker-compose logs -f agent-pm  # 只看 i10

# 重启服务
sudo docker-compose restart

# 重启单个 Agent
sudo docker-compose restart agent-pm

# 停止服务
sudo docker-compose down

# 更新镜像
sudo docker-compose pull
sudo docker-compose up -d

# 进入容器调试
sudo docker-compose exec agent-pm sh

# 查看资源使用
sudo docker stats
```

---

## 🔍 故障排查

### 1. Agent 无法启动

```bash
# 查看日志
sudo docker-compose logs agent-pm

# 常见原因
# - API Key 无效
# - Telegram Token 错误
# - 端口冲突
```

### 2. Claude API 错误

```bash
# 测试 API
sudo docker-compose exec agent-pm node -e "
const axios = require('axios');
axios.post('https://api.anthropic.com/v1/messages', {
  model: 'claude-3-haiku-20240307',
  messages: [{role: 'user', content: 'hi'}],
  max_tokens: 10
}, {
  headers: {'x-api-key': process.env.ANTHROPIC_API_KEY}
}).then(r => console.log('OK')).catch(e => console.error(e.message));
"
```

### 3. 重启所有服务

```bash
sudo docker-compose down
sudo docker-compose up -d --build
```

---

## 💡 扩展功能

### 添加图片分析能力

修改 `agents/agent.js`，添加 `claude-3-sonnet` 视觉能力：

```javascript
// 图片消息处理
bot.on('photo', async (msg) => {
  // 调用 Claude Vision API
  // ...
});
```

### 添加语音转文字

集成 Whisper API 或本地 Whisper 模型。

### 添加更多 Agent

复制 `agent-xxx` 服务，修改环境变量即可。

---

## 🔒 安全建议

1. **保护 .env 文件**
   ```bash
   chmod 600 .env
   ```

2. **使用防火墙**
   ```bash
   sudo ufw enable
   sudo ufw allow 22,80,443,18789/tcp
   ```

3. **定期备份**
   ```bash
   tar czvf i7-backup-$(date +%Y%m%d).tar.gz /opt/i7-docker
   ```

4. **日志清理**
   ```bash
   # 添加定时任务清理日志
   echo "0 0 * * 0 rm /opt/i7-docker/logs/*/*.log.{10..99}" | sudo crontab -
   ```

---

## 📞 支持

- **GitHub**: https://github.com/0dot1/ai-agent-team-docker
- **Telegram**: @i7_pm_bot

---

## 📄 License

MIT License