# === ETAP 1: Pobranie załatanej binarki MUSL bezpośrednio od producenta ===
FROM alpine:3.20 AS node-downloader
WORKDIR /tmp

# Instalacja curl i xz do rozpakowania paczki .tar.xz w Alpine
RUN apk add --no-cache curl xz

# Pobranie oficjalnego pakietu binarnego dedykowanego dla Alpine (linux-x64-musl)
RUN curl -fsSL https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-x64-musl.tar.xz -o node.tar.xz && \
    tar -xJf node.tar.xz && \
    mv node-v22.23.4-linux-x64-musl/bin/node /tmp/node

# === ETAP 2: Budowanie czystego obrazu Alpine z aplikacją Linkwarden ===
FROM alpine:3.20 AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Aktualizacja pakietów systemowych Alpine do najwyższych, bezpiecznych wersji
RUN apk update && apk upgrade --no-cache

# Kopiujemy całą, gotową strukturę aplikacji z oficjalnego obrazu Linkwardena
# Dzięki temu pomijamy Yarn PnP, Prisma i błędy kompilacji w chmurze
COPY --from=ghcr.io/linkwarden/linkwarden:latest /app ./

# Wstrzykujemy nową, załataną binarkę Node (musl) od producenta do naszego Alpine
COPY --from=node-downloader /tmp/node /usr/local/bin/node

# Odtworzenie oficjalnej struktury uprawnień użytkownika nieuprzywilejowanego w Alpine
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs && \
    mkdir -p /data/data && chown -R nextjs:nodejs /data

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
