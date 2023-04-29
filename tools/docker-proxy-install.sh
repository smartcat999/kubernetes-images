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
if [[ "$os" = "aarch64" ]]; then
  curl -SsL "https://github.com/v2fly/v2ray-core/releases/download/${V2Ray_VERSION}/v2ray-linux-arm64-v8a.zip" \
    -o v2ray.zip
elif [[ "$os" = "x86_64" ]]; then
  curl -SsL "https://github.com/v2fly/v2ray-core/releases/download/${V2Ray_VERSION}/v2ray-linux-64.zip" \
    -o v2ray.zip
fi

if [[ ! -f "v2ray.zip" ]]; then
  echo "Download File Error"
  exit
fi

unzip v2ray.zip -o /root/v2ray/

# 2. COPY file to /usr/local/bin/
cp /root/v2ray /usr/local/bin/

# 3. generate config
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
cat >>/etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

# start systemd
systemctl start v2ray.service

netstat -tlnup | grep v2ray

# docker pull proxy
mkdir -p /etc/systemd/system/docker.service.d

cat >/etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT}/"
Environment="HTTPS_PROXY=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT}/"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

systemctl restart docker

docker buildx create --name my-builder-proxy --bootstrap --use \
  --driver-opt env.http_proxy=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT} \
  --driver-opt env.https_proxy=socks5://${LISTEN_ADDRESS}:${LISTEN_PORT} \
  --driver-opt '"env.no_proxy='localhost,127.0.0.1'"' \
  --driver-opt network=host
