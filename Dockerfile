# === ETAP 1 & 2: Budowanie i Kompilacja (Builder na Debian-slim) ===
# Wykorzystujemy wersję slim, która posiada biblioteki glibc potrzebne dla Yarn v4
FROM node:22-bookworm-slim AS builder
WORKDIR /app

# Włączamy corepack dla automatycznej konfiguracji Yarn
RUN corepack enable

COPY package.json yarn.lock .yarnrc.yml ./

# Pobieramy i instalujemy zależności (flaga --no-immutable zapobiega konfliktom wersji)
RUN yarn install --no-immutable

COPY . .
RUN yarn prisma:generate
RUN yarn web:build

# === ETAP 3: Secure Runner (Środowisko produkcyjne z załatanym Node od NodeSource) ===
FROM debian:bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 1. Konfigurujemy oficjalne i bezpieczne źródło NodeSource dla Node v22
# 2. Instalujemy najnowszą, załataną wersję Node.js za pomocą apt-get, eliminując luki z Debiana
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://nodesource.com nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

# Odtworzenie oficjalnej struktury uprawnień użytkownika nieuprzywilejowanego
RUN groupadd --system --gid 1001 nodejs && \
    useradd --system --uid 1001 nextjs

# Kopiowanie czystego kodu produkcyjnego standalone (bez narzędzi dev)
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
