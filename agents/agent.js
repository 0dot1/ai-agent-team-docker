/**
 * i7 Team - Universal Agent (with OpenClaw support)
 * 通用 Agent 代码，支持直接调用 Claude 或通过 OpenClaw Gateway
 */

const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');
const redis = require('redis');
const winston = require('winston');
const express = require('express');

// ==================== 配置 ====================
const CONFIG = {
  role: process.env.AGENT_ROLE || 'generic',
  name: process.env.AGENT_NAME || 'AI Agent',
  telegramToken: process.env.TELEGRAM_BOT_TOKEN,
  claudeKey: process.env.ANTHROPIC_API_KEY,
  claudeModel: process.env.CLAUDE_MODEL || 'claude-3-haiku-20240307',
  systemPrompt: process.env.SYSTEM_PROMPT || '你是一个 helpful AI assistant',
  redisUrl: process.env.REDIS_URL || 'redis://redis:6379',
  openclawUrl: process.env.OPENCLAW_URL, // 可选
  port: process.env.PORT || 3000
};

// ==================== 日志 ====================
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: `/app/logs/${CONFIG.role}.log` })
  ]
});

// ==================== Redis 连接 ====================
let redisClient;
async function connectRedis() {
  try {
    redisClient = redis.createClient({ url: CONFIG.redisUrl });
    await redisClient.connect();
    logger.info('Redis connected');
  } catch (err) {
    logger.warn('Redis connection failed:', err.message);
  }
}

// ==================== Claude API 调用 ====================
async function askClaude(message, context = []) {
  const startTime = Date.now();
  
  // 方式1: 通过 OpenClaw Gateway (如果配置了)
  if (CONFIG.openclawUrl) {
    try {
      const response = await axios.post(`${CONFIG.openclawUrl}/api/v1/ai/chat`, {
        messages: [
          ...context,
          { role: 'user', content: `[${CONFIG.name}] ${message}` }
        ],
        model: CONFIG.claudeModel,
        max_tokens: 4000
      }, {
        timeout: 60000
      });

      logger.info('Claude API via OpenClaw', { duration: Date.now() - startTime });
      return response.data.content[0].text;
    } catch (error) {
      logger.warn('OpenClaw failed, falling back to direct API:', error.message);
    }
  }

  // 方式2: 直接调用 Claude API
  try {
    const messages = [
      ...context,
      { role: 'user', content: `[角色: ${CONFIG.name}]\n\n用户消息: ${message}` }
    ];

    const response = await axios.post('https://api.anthropic.com/v1/messages', {
      model: CONFIG.claudeModel,
      max_tokens: 4000,
      messages: messages
    }, {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CONFIG.claudeKey,
        'anthropic-version': '2023-06-01'
      },
      timeout: 60000
    });

    const duration = Date.now() - startTime;
    logger.info('Claude API direct call', { duration, model: CONFIG.claudeModel });

    return response.data.content[0].text;
  } catch (error) {
    logger.error('Claude API error:', {
      status: error.response?.status,
      message: error.response?.data?.error?.message || error.message
    });
    throw error;
  }
}

// ==================== 注册到 OpenClaw ====================
async function registerToOpenClaw() {
  if (!CONFIG.openclawUrl) return;
  
  try {
    await axios.post(`${CONFIG.openclawUrl}/api/v1/agents/register`, {
      id: CONFIG.role,
      name: CONFIG.name,
      role: CONFIG.role,
      token: CONFIG.telegramToken
    });
    logger.info(`Registered to OpenClaw: ${CONFIG.name}`);
  } catch (error) {
    logger.warn('Failed to register to OpenClaw:', error.message);
  }
}

// ==================== Telegram Bot ====================
const bot = new TelegramBot(CONFIG.telegramToken, { polling: true });

// 文本消息处理
bot.on('message', async (msg) => {
  // 跳过非文本消息
  if (!msg.text) return;
  if (msg.photo || msg.voice || msg.document || msg.video) {
    await handleMedia(msg);
    return;
  }

  const chatId = msg.chat.id;
  const text = msg.text;
  const from = msg.from?.username || msg.from?.first_name || '用户';

  logger.info(`Received message from ${from}: ${text.substring(0, 100)}`);

  try {
    // 显示正在输入
    await bot.sendChatAction(chatId, 'typing');

    // 获取历史上下文
    let context = [];
    if (redisClient) {
      const history = await redisClient.lRange(`chat:${chatId}`, 0, 9);
      context = history.map(h => JSON.parse(h));
    }

    // 调用 Claude (通过 OpenClaw 或直接)
    const reply = await askClaude(text, context);

    // 发送回复
    await bot.sendMessage(chatId, `【${CONFIG.name}】\n${reply}`, {
      reply_to_message_id: msg.message_id,
      parse_mode: 'Markdown'
    });

    // 保存到历史
    if (redisClient) {
      await redisClient.lPush(`chat:${chatId}`, JSON.stringify({
        role: 'user',
        content: text,
        timestamp: new Date().toISOString()
      }));
      await redisClient.lPush(`chat:${chatId}`, JSON.stringify({
        role: 'assistant',
        content: reply,
        timestamp: new Date().toISOString()
      }));
      await redisClient.lTrim(`chat:${chatId}`, 0, 99);
    }

    logger.info(`Reply sent to ${from}`);
  } catch (error) {
    logger.error('Message handler error:', error.message);
    await bot.sendMessage(chatId, 
      `【${CONFIG.name}】\n抱歉，服务暂时不可用：${error.response?.data?.error?.message || error.message}`,
      { reply_to_message_id: msg.message_id }
    );
  }
});

// 媒体消息处理
async function handleMedia(msg) {
  const chatId = msg.chat.id;
  
  if (msg.photo) {
    logger.info('Received photo');
    await bot.sendMessage(chatId, 
      `【${CONFIG.name}】\n收到图片！目前仅支持文本对话，图片分析功能即将上线。`,
      { reply_to_message_id: msg.message_id }
    );
  } else if (msg.voice) {
    logger.info('Received voice');
    await bot.sendMessage(chatId, 
      `【${CONFIG.name}】\n收到语音！请发送文字消息获得更准确回复。`,
      { reply_to_message_id: msg.message_id }
    );
  }
}

// 错误处理
bot.on('error', (err) => {
  logger.error('Bot error:', err.message);
});

bot.on('polling_error', (err) => {
  logger.error('Polling error:', err.message);
});

// ==================== HTTP 服务 (健康检查) ====================
const app = express();

app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    role: CONFIG.role,
    name: CONFIG.name,
    openclaw: CONFIG.openclawUrl || 'not configured',
    timestamp: new Date().toISOString()
  });
});

app.get('/stats', async (req, res) => {
  let redisStatus = 'disconnected';
  if (redisClient) {
    try {
      await redisClient.ping();
      redisStatus = 'connected';
    } catch (e) {
      redisStatus = 'error';
    }
  }
  
  res.json({
    role: CONFIG.role,
    name: CONFIG.name,
    redis: redisStatus,
    openclaw: CONFIG.openclawUrl || null,
    uptime: process.uptime()
  });
});

app.listen(CONFIG.port, () => {
  logger.info(`Health check server listening on port ${CONFIG.port}`);
});

// ==================== 启动 ====================
async function main() {
  logger.info(`Starting ${CONFIG.name} (${CONFIG.role})...`);
  logger.info(`Claude model: ${CONFIG.claudeModel}`);
  logger.info(`OpenClaw URL: ${CONFIG.openclawUrl || 'not configured (direct mode)'}`);
  
  await connectRedis();
  await registerToOpenClaw();
  
  logger.info(`${CONFIG.name} is ready!`);
  logger.info('Waiting for Telegram messages...');
}

main().catch(err => {
  logger.error('Startup error:', err);
  process.exit(1);
});

// 优雅关闭
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  if (redisClient) await redisClient.quit();
  process.exit(0);
});