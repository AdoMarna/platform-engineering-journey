FROM node:24-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src

# Numeric UID ("node"): Kubernetes runAsNonRoot can only verify numeric users.
USER 1000
EXPOSE 3000
CMD ["node", "src/server.js"]
