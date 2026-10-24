# === ETAP 1 & 2: Kompilacja i Budowanie (Builder) ===
FROM node:24-bookworm-slim AS builder
WORKDIR /app

# Aktywacja wbudowanego Corepack i zablokowanie Yarn na wersji projektu
RUN corepack enable && corepack prepare yarn@4.1.1 --activate

# Kopiowanie plików definicji pakietów
COPY package.json yarn.lock .yarnrc.yml ./

# WYJAŚNIENIE: Blokujemy wykonywanie skryptów postinstall Prismy podczas kroku install,
# aby uniknąć błędów niekompatybilności silników w chmurze GitHuba.
ENV YARN_ENABLE_SCRIPTS=0
RUN yarn install --no-immutable

# Kopiujemy resztę kodu źródłowego
COPY . .

# Ręcznie i bezpiecznie generujemy klienta Prisma z wymuszeniem ignorowania braku bazy
ENV PRISMA_CLI_BINARY_TARGETS=native
RUN yarn prisma:generate

# Kompilacja produkcyjna Next.js standalone
ENV NEXT_TELEMETRY_DISABLED=1
RUN yarn web:build

# === ETAP 3: Secure Runner (Środowisko produkcyjne Node 24) ===
FROM node:24-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Pełna aktualizacja bezpieczeństwa podstawowych bibliotek Debiana w locie
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Konfiguracja bezpiecznego użytkownika nieuprzywilejowanego
RUN groupadd --system --gid 1001 nodejs && \
    useradd --system --uid 1001 nextjs

# Kopiowanie wyłącznie zoptymalizowanych artefaktów produkcyjnych Next.js
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
