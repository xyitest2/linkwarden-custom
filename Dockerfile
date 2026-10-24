# === ETAP 1: Pobranie ZAWSZE NAJNOWSZEJ wersji z gałęzi przez APT ===
FROM debian:bookworm-slim AS node-downloader
WORKDIR /tmp

# Instalacja podstawowych pakietów do obsługi sieci i kluczy
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings

# KROK A: Pobranie klucza GPG (Użyj Części 1)
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# KROK B: Dodanie repozytorium do źródeł APT (Użyj Części 2 i 3)
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://nodesource.com nodistro main" > /etc/apt/sources.list.d/nodesource.list

# KROK C: Aktualizacja i instalacja najnowszego Node.js z repozytorium
RUN apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    cp /usr/bin/node /tmp/node

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
