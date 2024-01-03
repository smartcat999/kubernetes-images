FROM alpine:edge as openssl

ENV OPENSSL_VERSION openssl-3.1.4-quic1
ENV NODE_VERSION 21.5.0
ENV NODE_BRANCH main

WORKDIR /tmp

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add git openssh perl perl-text-template nasm \
    && apk add --no-cache libstdc++ \
    && apk add --no-cache --virtual .build-deps curl \
    && git config --global user.email "smartcat999@example.com" \
    && git config --global user.name "smartcat999"

RUN ARCH= && alpineArch="$(apk --print-arch)" \
      && case "${alpineArch##*-}" in \
        x86_64) \
          ARCH='x64' \
          CHECKSUM="8a637ef2fbac8c50b08129b8cbd80a8175a3d6c8b06615de100170d795af8668" \
          ;; \
        *) ;; \
      esac \
  && if [ -n "${CHECKSUM}" ]; then \
    echo "pass"; \
  else \
    echo "Building from source" \
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
    && cd ..; \
  fi

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


FROM alpine:edge as base

COPY --from=openssl /tmp/node /tmp/node

ENV NODE_VERSION 21.5.0

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        curl \
    && ARCH= && alpineArch="$(apk --print-arch)" \
      && case "${alpineArch##*-}" in \
        x86_64) \
          ARCH='x64' \
          CHECKSUM="8a637ef2fbac8c50b08129b8cbd80a8175a3d6c8b06615de100170d795af8668" \
          ;; \
        *) ;; \
      esac \
  && if [ -n "${CHECKSUM}" ]; then \
    set -eu; \
    curl -fsSLO --compressed "https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
    echo "$CHECKSUM  node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" | sha256sum -c - \
      && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
      && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
      && rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz"; \
  else \
    echo "Building from source" \
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
    # gpg keys listed at https://github.com/nodejs/node#release-keys
#    && for key in \
#      4ED778F539E3634C779C87C6D7062848A1AB005C \
#      141F07595B7B3FFE74309A937405533BE57C7D57 \
#      74F12602B6F1C4E913FAA37AD3A89613643B6201 \
#      DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
#      61FC681DFB92A079F1685E77973F295594EC4689 \
#      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
#      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
#      890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
#      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
#      108F52B48DB57BB0CC439B2997B01419BD92F80A \
#    ; do \
#      gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
#      gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
#    done \
#    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
#    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
#    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
#    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
#    && tar -xf "node-v$NODE_VERSION.tar.xz" \
#    && cd "node-v$NODE_VERSION" \
    && cd /tmp/node \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps-full \
    && cd ..; \
    #&& rm -rf "node-v$NODE_VERSION" \
    #&& rm "node-v$NODE_VERSION.tar.xz"; \
#    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  #&& rm -f "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
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

RUN rm /usr/bin/id && find /etc ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /etc ! -perm 640 -name "*.conf" 2>/dev/null | grep -v "/etc/resolv.conf" | xargs -I {} chmod 640 {} && \
    find /usr ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null | xargs -I {} chmod 600 {} && \
    find /usr ! -perm 640 -name "*.conf" 2>/dev/null | xargs -I {} chmod 640 {} && \
    rm /etc/ssl/cert.pem && rm -rf /etc/ssl/certs/ && rm -rf /etc/ssl1.1


COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]


FROM scratch

ENV NODE_VERSION 21.5.0

COPY --from=base / /

ENTRYPOINT ["docker-entrypoint.sh"]

CMD [ "node" ]