#FROM k8s.gcr.io/kube-proxy:v1.21.10 AS build
#FROM dockerhub.kubekey.local/huawei/kube-proxy:v1.21.10 AS build
FROM 2030047311/kube-proxy:v1.21.10 AS build

#FROM gcr.io/k8s-staging-build-image/distroless-iptables-arm64:v0.2.1 AS base
FROM dockerhub.kubekey.local/huawei/distroless-iptables-arm64:v0.2.1 as base

COPY --from=build /usr/local/bin/kube-proxy /usr/local/bin/kube-proxy

FROM scratch

COPY --from=base / /