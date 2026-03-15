# i7 Team Agent Dockerfile
# 通用 Agent 镜像，通过环境变量配置不同角色

FROM node:20-alpine

# 安装必要依赖
RUN apk add --no-cache \
    curl \
    ca-certificates

# 创建工作目录
WORKDIR /app

# 复制 package.json
COPY package.json ./

# 安装依赖
RUN npm install

# 复制 Agent 代码
COPY agent.js ./

# 创建日志目录
RUN mkdir -p /app/logs

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 启动 Agent
CMD ["node", "agent.js"]