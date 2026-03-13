const express = require('express');
const axios = require('axios');
const redis = require('redis');
const winston = require('winston');
require('dotenv').config();

// Setup logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});

const app = express();
app.use(express.json());

// Agent configuration
const AGENT_ROLE = process.env.AGENT_ROLE || 'generic';
const MODEL = process.env.AGENT_MODEL || 'claude-3-5-sonnet';
const API_KEY = process.env.ANTHROPIC_API_KEY || process.env.OPENAI_API_KEY;

// Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});
redisClient.connect();

// System prompts for each role
const SYSTEM_PROMPTS = {
  product_manager: `你是一位资深产品经理。负责需求分析、PRD撰写、项目规划、任务分配和进度跟踪。
输出格式：
1. 收到需求 → 24小时内给出评估
2. 创建PRD：背景、目标、功能列表、验收标准、排期
3. 任务分配：@角色 + 具体任务 + deadline
4. 每日站会：昨日进展/今日计划/阻塞问题`,

  ui_designer: `你是一位UI/UX设计专家。负责交互设计、视觉设计、设计规范制定。
输出格式：
1. 收到需求 → 询问目标用户和品牌调性
2. 输出3个草图方案
3. 确认后输出高保真设计
4. 标注切图资源交付开发`,

  frontend_dev: `你是一位前端架构师。精通React/Vue/TypeScript/TailwindCSS。
代码规范：TypeScript严格模式、组件化、性能优化、安全XSS防护。
输出：源代码+README+组件文档`,

  backend_dev: `你是一位后端工程师。精通Node.js/Python/Go、数据库设计、API设计。
规范：RESTful、数据库三范式、错误处理、日志记录。
输出：源码+API文档+部署脚本`,

  app_dev: `你是一位移动端开发专家。精通Flutter/React Native/iOS/Android。
流程：评估跨平台vs原生 → 开发 → 测试 → 上架。
输出：源码+测试包+上架材料`,

  security_eng: `你是一位网络安全专家。负责代码审查、漏洞扫描、渗透测试。
检查项：SQL注入、XSS、CSRF、权限控制、敏感数据加密。
输出：安全报告+修复建议`,

  operations: `你是一位增长运营专家。擅长内容运营、用户增长、数据分析。
平台：小红书/抖音/公众号。公式：数字+结果+情绪词。
输出：运营方案+内容脚本+数据报表`
};

// Call AI Model
async function callModel(messages) {
  const systemPrompt = SYSTEM_PROMPTS[AGENT_ROLE] || 'You are a helpful assistant.';
  
  try {
    if (MODEL.includes('claude')) {
      // Anthropic Claude
      const response = await axios.post('https://api.anthropic.com/v1/messages', {
        model: MODEL,
        max_tokens: 4096,
        system: systemPrompt,
        messages: messages
      }, {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        }
      });
      return response.data.content[0].text;
    } else {
      // OpenAI GPT
      const response = await axios.post('https://api.openai.com/v1/chat/completions', {
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          ...messages
        ]
      }, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
        }
      });
      return response.data.choices[0].message.content;
    }
  } catch (error) {
    logger.error('Model API error:', error.message);
    return `Error: ${error.message}`;
  }
}

// Process message
app.post('/process', async (req, res) => {
  const { message, from, context } = req.body;
  
  logger.info(`Processing message for ${AGENT_ROLE}`, { from, message: message.substring(0, 50) });
  
  try {
    // Build messages array from context
    const messages = [];
    if (context && context.length > 0) {
      for (const msg of context) {
        messages.push({
          role: msg.role,
          content: msg.content
        });
      }
    }
    
    // Add current message
    messages.push({
      role: 'user',
      content: `From: ${from}\nMessage: ${message}`
    });
    
    // Call AI model
    const response = await callModel(messages);
    
    res.json({
      success: true,
      message: response,
      agent: AGENT_ROLE,
      model: MODEL
    });
    
  } catch (error) {
    logger.error('Processing error:', error);
    res.status(500).json({
      error: true,
      message: 'Processing failed'
    });
  }
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    role: AGENT_ROLE,
    model: MODEL
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`${AGENT_ROLE} agent listening on port ${PORT}`);
});