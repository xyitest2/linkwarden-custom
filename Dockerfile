FROM node:22-alpine AS builder
WORKDIR /app

# Włączamy corepack dla automatycznej obsługi Yarn
RUN corepack enable

COPY package.json yarn.lock .yarnrc.yml ./

# ZMIANA: Usuwamy flagę --immutable, aby Yarn mógł zaktualizować zależności pod Node 22
RUN yarn install --no-immutable

COPY . .
RUN yarn prisma:generate
RUN yarn web:build

FROM alpine:3.20 AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN apk update && apk upgrade --no-cache && apk add --no-cache nodejs ca-certificates

RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./package.json

RUN mkdir -p /data/data && chown -R nextjs:nodejs /data
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
