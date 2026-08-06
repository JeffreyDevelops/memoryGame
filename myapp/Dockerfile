FROM node:24-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --chown=node:node . .

USER node
EXPOSE 2002

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:2002/ >/dev/null 2>&1 || exit 1

CMD ["node", "./bin/www"]
