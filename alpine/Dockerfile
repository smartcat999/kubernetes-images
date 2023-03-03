FROM alpine:3.16 as base

# RUN apk upgrade busybox --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main


RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    set -eux && \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk upgrade --available && sync && \
    rm /var/cache/apk/*

FROM scratch

COPY --from=base / /

CMD ["sh"]



