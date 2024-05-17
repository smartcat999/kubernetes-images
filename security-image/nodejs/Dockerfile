FROM alpine:3.16 as openssl

ENV OPENSSL_VERSION openssl-3.1.5-quic1
ENV NODE_VERSION 21.5.0
ENV NODE_BRANCH v21.5.0

WORKDIR /tmp

RUN apk add git openssh perl perl-text-template nasm \
    && apk add --no-cache libstdc++ \
    && apk add --no-cache --virtual .build-deps curl \
    && git config --global user.email "smartcat999@example.com" \
    && git config --global user.name "smartcat999"

RUN ARCH= && alpineArch="$(apk --print-arch)" \
    && apk update \
    && echo "Building from source" \
    # backup build
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python3 \
    && git clone https://github.com/nodejs/node.git \
    && cd node  \
    && git checkout ${NODE_BRANCH} \
    && cd ..

RUN git clone https://github.com/quictls/openssl  \
    && cd openssl  \
    && git checkout $OPENSSL_VERSION \
    && cd ../node/deps/openssl \
    && rm -rf openssl \
    && cp -R ../../../openssl openssl \
    && rm -rf openssl/.git* openssl/.travis* \
    && git add --all openssl \
    && git commit openssl -m "deps: upgrade openssl sources to quictls/${OPENSSL_VERSION}"

RUN cd /tmp/node \
    && make -C deps/openssl/config clean \
    && make -C deps/openssl/config \
    && git add deps/openssl/config/archs \
    && git add deps/openssl/openssl \
    && git commit -m "deps: update archs files for quictls/${OPENSSL_VERSION}"


FROM alpine:3.16 as base

COPY --from=openssl /tmp/node /tmp/node

ENV NODE_VERSION 21.5.0

RUN apk update \
#    && addgroup -g 1000 node \
#    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps curl \
    && echo "Building from source" \
    # backup build
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python3 \
    && cd /tmp/node \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
  && apk del .build-deps \
  # smoke tests
  && node --version \
  && npm --version \
  && rm -rf /tmp/node

ENV YARN_VERSION 1.22.19

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
#  && for key in \
#    6A010C5166006599AA17F08146C2130DFD2497F5 \
#  ; do \
#    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
#    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
#  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
#  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
#  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz \
#  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && apk del .build-deps-yarn \
  # smoke test
  && yarn --version

RUN apk add shadow && \
    usermod -s /sbin/nologin -g nogroup sync && \
    usermod -s /sbin/nologin -g nogroup shutdown && \
    usermod -s /sbin/nologin -g nogroup halt && \
    usermod -s /sbin/nologin -g nogroup operator && \
    apk del shadow

RUN apk update && \
    apk --no-cache upgrade --available && \
    sync && \
    rm /var/cache/apk/*

RUN npm uninstall -g npm

RUN rm /usr/bin/id && find /etc ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /etc ! -perm 640 -name "*.conf" 2>/dev/null | grep -v "/etc/resolv.conf" | xargs -I {} chmod 640 {} && \
    find /usr ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /usr ! -perm 640 -name "*.conf" 2>/dev/null | xargs -I {} chmod 640 {} && \
    rm /etc/ssl/cert.pem && rm -rf /etc/ssl/certs/ && rm -rf /etc/ssl1.1

RUN rm /usr/bin/nc

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]


FROM scratch

ENV NODE_VERSION 21.5.0

COPY --from=base / /

ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]