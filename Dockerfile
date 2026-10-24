# === ETAP 1 & 2: Pełna kompilacja (Builder z oficjalnym Node 24) ===
# Korzystamy z pełnego obrazu od twórców Node.js, który zawiera niezbędne biblioteki do kompilacji Yarn v4
FROM node:24-bookworm AS builder
WORKDIR /app

# Instalujemy podstawowe kompilatory dla binarów C++/esbuild wewnątrz Debiana
RUN apt-get update && apt-get install -y --no-install-recommends build-essential python3 git && rm -rf /var/lib/apt/lists/*

# Włączamy corepack dla automatycznej obsługi Yarn
RUN corepack enable

COPY package.json yarn.lock .yarnrc.yml ./

# Blokujemy wykonywanie skryptów postinstall, które wywalają build na nowym Node w chmurze
ENV YARN_ENABLE_SCRIPTS=0

# Pobieramy i instalujemy zależności (flaga --no-immutable pozwala na adaptację)
RUN yarn install --no-immutable

COPY . .
RUN yarn prisma:generate
RUN yarn web:build

# === ETAP 3: Secure Runner (Środowisko produkcyjne bez podatności) ===
# Zaczynamy od czystego, odchudzonego systemu Debian
FROM debian:bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Aktualizujemy wyłącznie biblioteki systemowe bazy OS (np. OpenSSL) za pomocą apt-get.
# NIE instalujemy stąd Node.js!
RUN echo "deb http://debian.org bookworm main" > /etc/apt/sources.list && \
    echo "deb http://debian.org-security bookworm-security main" >> /etc/apt/sources.list && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# KLUCZOWY KROK: Kopiujemy oficjalny, w 100% załatany binar Node.js 24 bezpośrednio 
# z etapu builder (stworzonego przez zespół Node.js), całkowicie ignorując brak paczek w Debianie!
COPY --from=builder /usr/local/bin/node /usr/local/bin/node
COPY --from=builder /usr/local/include/node /usr/local/include/node
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/bin/node /usr/local/bin/node-app

# Odtworzenie struktury użytkowników Linkwardena
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

# Uruchomienie za pomocą bezpiecznego, skopiowanego binaru Node.js
CMD ["node", "server.js"]
