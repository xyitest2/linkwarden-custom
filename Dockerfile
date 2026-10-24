# === ETAP 1: Pobranie ZAWSZE NAJNOWSZEJ wersji z gałęzi przez APT ===
FROM debian:bookworm-slim AS node-downloader
WORKDIR /tmp

# Instalacja podstawowych pakietów do obsługi sieci i kluczy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs

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
