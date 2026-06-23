FROM alpine:3.21

RUN apk add --no-cache \
    postgresql16-client \
    aws-cli \
    bash \
    tzdata

COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/backup.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
