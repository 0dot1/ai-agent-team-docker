const express = require('express');
const redis = require('redis');
const axios = require('axios');
const winston = require('winston');
require('dotenv').config();

// Logger setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: '/app/logs/coordinator.log' })
  ]
});

const app = express();
app.use(express.json());

// Redis client
const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379'
});

redisClient.on('error', (err) => logger.error('Redis error:', err));
redisClient.connect();

// Agent registry
const AGENTS = {
  pm: { name: 'Product Manager', port: 3001, model: 'claude-3-opus' },
  ui: { name: 'UI Designer', port: 3002, model: 'claude-3-5-sonnet' },
  frontend: { name: 'Frontend Dev', port: 3003, model: 'claude-3-5-sonnet' },
  backend: { name: 'Backend Dev', port: 3004, model: 'claude-3-5-sonnet' },
  app: { name: 'App Dev', port: 3005, model: 'claude-3-5-sonnet' },
  security: { name: 'Security Eng', port: 3006, model: 'gpt-4o' },
  ops: { name: 'Operations', port: 3007, model: 'gpt-4o' }
};

// Message router
async function routeMessage(message, from, context = {}) {
  logger.info('Routing message', { from, message: message.substring(0, 100) });
  
  // Parse mentions
  const mentions = message.match(/@(\w+)/g) || [];
  
  if (mentions.length === 0) {
    // No mention, route to PM for triage
    return await forwardToAgent('pm', message, from, context);
  }
  
  // Route to mentioned agents
  const results = [];
  for (const mention of mentions) {
    const agentId = mention.replace('@', '').toLowerCase();
    if (AGENTS[agentId]) {
      const result = await forwardToAgent(agentId, message, from, context);
      results.push(result);
    }
  }
  
  return results;
}

// Forward to specific agent
async function forwardToAgent(agentId, message, from, context) {
  const agent = AGENTS[agentId];
  if (!agent) {
    logger.warn(`Unknown agent: ${agentId}`);
    return null;
  }
  
  try {
    // Get recent context from Redis
    const contextKey = `context:${agentId}`;
    const recentContext = await redisClient.lRange(contextKey, 0, 9);
    
    // Build request
    const request = {
      message,
      from,
      context: recentContext.map(JSON.parse),
      timestamp: new Date().toISOString()
    };
    
    // Store in Redis
    await redisClient.lPush(contextKey, JSON.stringify({
      role: 'user',
      content: message,
      from,
      timestamp: request.timestamp
    }));
    await redisClient.lTrim(contextKey, 0, 99);
    
    // Call agent service
    const response = await axios.post(
      `http://agent-${agentId}:3000/process`,
      request,
      { timeout: 60000 }
    );
    
    // Store response
    await redisClient.lPush(contextKey, JSON.stringify({
      role: 'assistant',
      content: response.data.message,
      agent: agentId,
      timestamp: new Date().toISOString()
    }));
    
    logger.info(`Message routed to ${agentId}`, { 
      response: response.data.message.substring(0, 100) 
    });
    
    return response.data;
    
  } catch (error) {
    logger.error(`Error routing to ${agentId}:`, error.message);
    return {
      error: true,
      message: `Failed to reach ${agent.name}. Please try again.`
    };
  }
}

// API Routes
app.post('/route', async (req, res) => {
  const { message, from, context } = req.body;
  
  if (!message || !from) {
    return res.status(400).json({ error: 'Message and from are required' });
  }
  
  try {
    const result = await routeMessage(message, from, context);
    res.json({ success: true, result });
  } catch (error) {
    logger.error('Routing error:', error);
    res.status(500).json({ error: 'Routing failed' });
  }
});

app.get('/agents', (req, res) => {
  res.json(AGENTS);
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', agents: Object.keys(AGENTS) });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Coordinator listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  await redisClient.quit();
  process.exit(0);
});