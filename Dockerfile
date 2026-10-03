# Evolution API 2.3.7 + fix de vinculación (companion_reg_refresh)
# Fork AlmogCohen/evolution-api, PR #3, commit fijado y revisado.
# Misma base de datos que la v2.3.7 oficial (sin migraciones nuevas).
# Rollback: volver la imagen a evoapicloud/evolution-api:v2.3.7

FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

ARG FIX_COMMIT=c84466e32f96ed0fe6b0d4292d48bd46adfa6ee7

RUN git clone https://github.com/AlmogCohen/evolution-api.git . && \
    git fetch origin pull/3/head && \
    git checkout ${FIX_COMMIT}

# postinstall (patch-package) aplica patches/baileys+7.0.0-rc14.patch
RUN npm ci --silent

RUN cp ./.env.example ./.env && \
    chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

FROM node:24-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
