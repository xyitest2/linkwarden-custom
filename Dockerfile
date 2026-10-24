# === ETAP 1: Pobranie ZAWSZE NAJNOWSZEJ wersji z gałęzi przez APT ===
FROM debian:bookworm-slim AS node-downloader
WORKDIR /tmp

# Instalacja podstawowych pakietów do obsługi sieci i kluczy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - apt-get install -y nodejs

# === ETAP 2: Chirurgia i wstrzyknięcie binaru do oficjalnego Linkwardena ===
FROM ghcr.io/linkwarden/linkwarden:latest
USER root

# Podnosimy bezpieczeństwo warstwy OS (Debian) w oficjalnym obrazie
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Nadpisujemy stary, podatny binar nową, automatycznie pobraną wersją z NodeSource
COPY --from=node-downloader /tmp/node /usr/local/bin/node

# Przywracamy domyślnego, nieuprzywilejowanego użytkownika Linkwardena
USER nextjs

CMD ["node", "server.js"]
