/**
 * OpenClaw Gateway - i7 Team Edition
 * 兼容 OpenClaw API 的轻量级网关
 * 
 * 功能：
 * 1. Agent 注册与管理
 * 2. 消息路由
 * 3. Claude API 代理
 * 4. 健康检查
 */

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const redis = require('redis');
const winston = require('winston');

// ==================== 配置 ====================
const CONFIG = {
  port: process.env.OPENCLAW_PORT || 18789,
  redisUrl: process.env.REDIS_URL || 'redis://redis:6379',
  claudeKey: process.env.ANTHROPIC_API_KEY,
  claudeModel: process.env.CLAUDE_MODEL || 'claude-3-haiku-20240307'
};

// ==================== 日志 ====================
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});

// ==================== Redis 连接 ====================
let redisClient;
async function connectRedis() {
  try {
    redisClient = redis.createClient({ url: CONFIG.redisUrl });
    await redisClient.connect();
    logger.info('Redis connected');
  } catch (err) {
    logger.error('Redis connection failed:', err.message);
  }
}

// ==================== Express 应用 ====================
const app = express();
app.use(cors());
app.use(express.json());

// Agent 注册表
const agents = new Map();

// ==================== 路由 ====================

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    version: '1.0.0',
    gateway: 'openclaw-i7',
    timestamp: new Date().toISOString(),
    agents: agents.size,
    redis: redisClient?.isReady ? 'connected' : 'disconnected'
  });
});

// Agent 注册
app.post('/api/v1/agents/register', async (req, res) => {
  const { id, name, role, token } = req.body;
  
  if (!id || !name || !role) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  
  agents.set(id, {
    id,
    name,
    role,
    token,
    registeredAt: new Date().toISOString(),
    status: 'active'
  });
  
  logger.info(`Agent registered: ${name} (${id})`);
  
  res.json({
    success: true,
    agent: { id, name, role, status: 'active' }
  });
});

// 获取所有 Agent
app.get('/api/v1/agents', (req, res) => {
  res.json({
    agents: Array.from(agents.values()),
    count: agents.size
  });
});

// 调用 Claude API
app.post('/api/v1/ai/chat', async (req, res) => {
  const { messages, model, max_tokens } = req.body;
  
  if (!messages || !Array.isArray(messages)) {
    return res.status(400).json({ error: 'Invalid messages format' });
  }
  
  try {
    const response = await axios.post('https://api.anthropic.com/v1/messages', {
      model: model || CONFIG.claudeModel,
      max_tokens: max_tokens || 4000,
      messages
    }, {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CONFIG.claudeKey,
        'anthropic-version': '2023-06-01'
      },
      timeout: 60000
    });
    
    res.json(response.data);
  } catch (error) {
    logger.error('Claude API error:', error.response?.data || error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data?.error?.message || 'Internal server error'
    });
  }
});

// 发送消息到 Agent
app.post('/api/v1/agents/:id/message', async (req, res) => {
  const { id } = req.params;
  const { message, userId } = req.body;
  
  const agent = agents.get(id);
  if (!agent) {
    return res.status(404).json({ error: 'Agent not found' });
  }
  
  // 保存到 Redis 队列
  if (redisClient) {
    await redisClient.lPush(`agent:${id}:messages`, JSON.stringify({
      message,
      userId,
      timestamp: new Date().toISOString()
    }));
  }
  
  logger.info(`Message queued for ${agent.name}: ${message.substring(0, 50)}`);
  
  res.json({
    success: true,
    queued: true,
    agent: agent.name
  });
});

// 获取 Agent 状态
app.get('/api/v1/agents/:id/status', (req, res) => {
  const { id } = req.params;
  const agent = agents.get(id);
  
  if (!agent) {
    return res.status(404).json({ error: 'Agent not found' });
  }
  
  res.json({
    id: agent.id,
    name: agent.name,
    role: agent.role,
    status: agent.status,
    registeredAt: agent.registeredAt
  });
});

// 全局配置
app.get('/api/v1/config', (req, res) => {
  res.json({
    claudeModel: CONFIG.claudeModel,
    version: '1.0.0',
    features: ['claude-api', 'agent-management', 'redis-queue']
  });
});

// 404 处理
app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

// 错误处理
app.use((err, req, res, next) => {
  logger.error('Express error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ==================== 启动 ====================
async function main() {
  await connectRedis();
  
  app.listen(CONFIG.port, () => {
    logger.info(`OpenClaw Gateway listening on port ${CONFIG.port}`);
    logger.info(`Health check: http://localhost:${CONFIG.port}/health`);
  });
}

main().catch(err => {
  logger.error('Startup error:', err);
  process.exit(1);
});