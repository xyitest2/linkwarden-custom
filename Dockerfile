# === ETAP 1: Pobranie ZAWSZE NAJNOWSZEJ wersji z gałęzi przez APT ===
FROM debian:bookworm-slim AS node-downloader
WORKDIR /tmp

# Instalacja podstawowych pakietów do obsługi sieci i kluczy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl zx-utils

# RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs

# BEZPIECZNE ADRESY (Rozbite na części, aby uniknąć błędów parsera w chmurze GitHuba)
ENV NODE_URL_BASE="https://nodejs.org"
ENV NODE_FILE="node-v22.23.4-linux-x64.tar.xz"

# Pobranie paczki bezpośrednio z oficjalnych serwerów producenta i wyciągnięcie binaru node
RUN curl -fsSL "${NODE_URL_BASE}/${NODE_FILE}" -o node.tar.xz && tar -xJf node.tar.xz && \
    mv "${NODE_DIR}/bin/node" /usr/local/bin/node

# === ETAP 2: Chirurgia i wstrzyknięcie binaru do oficjalnego Linkwardena ===
FROM ghcr.io/linkwarden/linkwarden:latest
USER root

# Podnosimy bezpieczeństwo warstwy OS (Debian) w oficjalnym obrazie
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1001 nodejs || true && \
    useradd --system --uid 1001 --gid nodejs nextjs || true

# Przywracamy domyślnego, nieuprzywilejowanego użytkownika Linkwardena
WORKDIR /app/apps/web
USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
