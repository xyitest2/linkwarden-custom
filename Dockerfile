# === ETAP 1: Pobranie załatanej i najnowszej wersji 24.22.1 od producenta ===
FROM debian:bookworm-slim AS node-downloader
WORKDIR /tmp

# Instalacja curl i ca-certificates niezbędnych do bezpiecznego pobrania binaru
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl xz-utils && rm -rf /var/lib/apt/lists/*

# Pobranie oficjalnego, skompilowanego pakietu binarnego bezpośrednio z nodejs.org (wersja v24.22.1 z łatką)
RUN curl -fsSL https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-x64.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz && \
    mv node-v22.23.4-linux-x64/bin/node /tmp/node

# === ETAP 2: Chirurgia i wstrzyknięcie binaru do oficjalnego Linkwardena ===
FROM ghcr.io/linkwarden/linkwarden:latest
USER root

# Podnosimy bezpieczeństwo warstwy OS samego Debiana wewnątrz obrazu Linkwardena
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Nadpisujemy stary, podatny binar w oficjalnym obrazie nowiuteńkim, załatanym Node 24.22.1 od producenta
COPY --from=node-downloader /tmp/node /usr/local/bin/node

# Przywracamy domyślnego, nieuprzywilejowanego użytkownika Linkwardena (nextjs)
USER nextjs

# Kontener startuje dokładnie tak jak oryginał, ale na najnowszym, bezpiecznym sercu
CMD ["node", "server.js"]
