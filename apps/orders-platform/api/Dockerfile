FROM node:24-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
# npm is only needed to install: removing it drops its bundled dependencies (and their CVEs).
RUN npm ci --omit=dev \
 && npm cache clean --force \
 && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

COPY src ./src

# Numeric UID ("node"): Kubernetes runAsNonRoot can only verify numeric users.
USER 1000
EXPOSE 3000
CMD ["node", "src/server.js"]
