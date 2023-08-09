#!/bin/bash

LISTEN_ADDRESS=127.0.0.1
LISTEN_PORT=1080
PROXY_ADDRESS=""
PROXY_PORT=""
UUID=""
V2Ray_VERSION=v5.4.1

# 1. download binary package
# https://github.com/v2fly/v2ray-core/releases
# shellcheck disable=SC2164
cd /root/
os=$(uname -m)


if [[ ! -f "v2ray.zip" ]]; then
  if [[ "$os" = "aarch64" ]]; then
    curl -SsL "https://github.com/v2fly/v2ray-core/releases/download/${V2Ray_VERSION}/v2ray-linux-arm64-v8a.zip" \
      -o v2ray.zip
  elif [[ "$os" = "x86_64" ]]; then
    curl -SsL "https://github.com/v2fly/v2ray-core/releases/download/${V2Ray_VERSION}/v2ray-linux-64.zip" \
      -o v2ray.zip
  fi

  if [[ ! -f "v2ray.zip" ]]; then
    echo "Download File Error"
  fi

  exit
fi

unzip v2ray.zip -d /root/v2ray/

# 2. COPY file to /usr/local/bin/
cp -r  /root/v2ray /usr/local/v2ray

# 3. generate config
mkdir -p /usr/local/etc/v2ray/
cat >/usr/local/etc/v2ray/config.json <<EOF
{
    "inbounds": [
        {
            "port": "${LISTEN_PORT}",
            "listen": "${LISTEN_ADDRESS}",
            "protocol": "socks",
            "settings": {
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "vmess",
            "settings": {
                "vnext": [
                    {
                        "address": "${PROXY_ADDRESS}",
                        "port": "${PROXY_PORT}",
                        "users": [
                            {
                                "id": "${UUID}"
                            }
                        ]
                    }
                ]
            }
        },
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ],
    "routing": {
        "domainStrategy": "IPOnDemand",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "direct"
            }
        ]
    }
}
EOF

# 4. generate systemd config
cat >/etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/v2ray/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

# start systemd
systemctl start v2ray.service

netstat -tlnup | grep v2ray

# protocol: socks5 -> http
# 1. apt-get install privoxy

# 2. vim /etc/privoxy/config
# forward-socks5 /               127.0.0.1:1080 .
# listen-address localhost:1081

# 3. systemctl restart privoxy


# docker pull proxy
mkdir -p /etc/systemd/system/docker.service.d

cat >/etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT}/"
Environment="HTTPS_PROXY=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT}/"
Environment="NO_PROXY=localhost,127.0.0.0/8,172.0.0.0/8,192.0.0.0/8,10.0.0.0/8"
EOF

if [ -d "$HOME/.docker/config.json" ]; then
  echo "$HOME/.docker/config.json already existed"
  echo "Please set proxies.default.httpProxy in $HOME/.docker/config.json"
  echo "Please set proxies.default.httpsProxy in $HOME/.docker/config.json"
  echo "Please set proxies.default.noProxy in $HOME/.docker/config.json"
else
  cat > ~/.docker/config.json <<EOF
{
    "proxies":
    {
        "default":
        {
            "httpProxy": "http://172.31.189.234:1081",
            "httpsProxy": "http://172.31.189.234:1081",
            "noProxy": "127.0.0.0/8,192.0.0.0/8,172.0.0.0/8,10.0.0.0/8,localhost"
        }
    }
}
EOF
  fi
systemctl restart docker

docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx create --name my-builder-proxy --bootstrap --use \
  --driver-opt env.http_proxy=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT} \
  --driver-opt env.https_proxy=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT} \
  --driver-opt '"env.no_proxy='localhost,127.0.0.0/8,172.0.0.0/8,192.0.0.0/8,10.0.0.0/8'"' \
  --driver-opt network=host

#docker buildx create --name my-builder-proxy --bootstrap --use \
#  --driver-opt env.http_proxy=socks5://127.0.01:1080 \
#  --driver-opt env.https_proxy=socks5://127.0.01:1080 \
#  --driver-opt '"env.no_proxy='localhost,127.0.0.0/8,172.0.0.0/8,192.0.0.0/8,10.0.0.0/8'"' \
#  --driver-opt network=host