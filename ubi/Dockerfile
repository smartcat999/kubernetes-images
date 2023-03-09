FROM registry.access.redhat.com/ubi9/ubi-minimal:latest as ubi9

FROM registry.access.redhat.com/ubi8/ubi-minimal:8.5 as ubi

RUN microdnf update && rm /etc/yum.repos.d/ubi.repo

COPY --from=ubi9 /etc/yum.repos.d/ubi.repo /etc/yum.repos.d/

RUN microdnf update

CMD ["sh"]