# OpenClaw Gateway for i7 Team
# 兼容 OpenClaw API 的轻量级网关

FROM node:20-alpine

WORKDIR /app

# 安装依赖
RUN apk add --no-cache curl

# 创建 package.json
COPY package.json ./
RUN npm install

# 复制网关代码
COPY gateway.js ./

EXPOSE 18789

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

CMD ["node", "gateway.js"]