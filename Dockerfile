# === ETAP 1 & 2: Budowanie i Kompilacja (Builder) ===
FROM node:22-alpine AS builder
WORKDIR /app

# Instalujemy niezbędne pakiety systemowe do kompilacji natywnych binarów w Alpine
RUN apk add --no-cache build-base python3 make g++ unzip

# Włączamy corepack dla automatycznej obsługi Yarn
RUN corepack enable

COPY package.json yarn.lock .yarnrc.yml ./

# Pobieramy i aktualizujemy zależności
RUN yarn install --no-immutable

COPY . .
RUN yarn prisma:generate
RUN yarn web:build

# === ETAP 2: Secure Runner (Środowisko produkcyjne Alpine) ===
FROM alpine:3.20 AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Czyste, załatane środowisko uruchomieniowe
RUN apk update && apk upgrade --no-cache && apk add --no-cache nodejs ca-certificates

# Bezpieczna struktura użytkowników
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs

# Kopiowanie czystego kodu produkcyjnego standalone
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
