FROM alpine:edge as base

RUN apk update && \
    apk --no-cache upgrade --available && \
    sync && \
    rm /var/cache/apk/*

RUN rm /usr/bin/id && find /etc ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /etc ! -perm 640 -name "*.conf" 2>/dev/null | grep -v "/etc/resolv.conf" | xargs -I {} chmod 640 {} && \
    find /usr ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /usr ! -perm 640 -name "*.conf" 2>/dev/null | xargs -I {} chmod 640 {} && \
    rm /etc/ssl/cert.pem


FROM scratch

COPY --from=base / /

CMD ["sh"]
