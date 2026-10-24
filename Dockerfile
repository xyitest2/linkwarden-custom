# === ETAP 1 & 2: Pełna kompilacja (Builder z narzędziami systemowymi) ===
FROM node:22-bookworm AS builder
WORKDIR /app

# Instalujemy python3 i podstawowe narzędzia budowania dla binarów C++/esbuild
RUN apt-get update && apt-get install -y python3 make g++ gcc libpixman-1-dev cairo-dev pango-dev git && rm -rf /var/lib/apt/lists/*

# Włączamy corepack i aktywujemy dokładnie tę wersję Yarn, którą wymusza projekt
RUN corepack enable && corepack prepare yarn@4.1.1 --activate

COPY package.json yarn.lock .yarnrc.yml ./

# Pobieramy i instalujemy zależności (flaga --no-immutable pozwala na adaptację)
RUN yarn install --no-immutable

COPY . .
RUN yarn prisma:generate
RUN yarn web:build

# === ETAP 3: Secure Runner (Czyste środowisko produkcyjne z NodeSource) ===
FROM debian:bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Konfigurujemy oficjalne i bezpieczne źródło NodeSource dla Node v22
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
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

# Kopiowanie czystego kodu produkcyjnego standalone (Next.js)
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
