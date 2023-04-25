FROM alpine:edge as base

RUN apk update && \
    apk --no-cache upgrade --available && \
    sync && \
    rm /var/cache/apk/*

ADD ./permission.sh /root/

RUN rm /usr/bin/id && ./permission.sh

FROM scratch

COPY --from=base / /

CMD ["sh"]
