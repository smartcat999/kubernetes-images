FROM 2030047311/nodejs20-debian12:nonroot-debug as os


FROM 2030047311/nodejs20-debian12:nonroot as base

USER root
COPY --from=os /busybox/sh /bin/sh
COPY --from=os /busybox/ /busybox/

#ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/busybox

RUN /busybox/rm -rf /usr/share/gcc /usr/share/gdb /etc/ssl/certs /usr/lib/ssl/cert.pem /busybox /bin/sh

FROM scratch

USER nonroot

COPY --from=base / /