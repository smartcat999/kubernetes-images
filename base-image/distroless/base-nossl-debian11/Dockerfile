FROM 2030047311/base-nossl-debian11:nonroot-debug as os


FROM 2030047311/base-nossl-debian11:nonroot as base

USER root
COPY --from=os /busybox/sh /bin/sh
COPY --from=os /busybox/ /busybox/

RUN /busybox/rm -rf /usr/share/gcc /usr/share/gdb /etc/ssl/certs /usr/lib/ssl/cert.pem /busybox /bin/sh

FROM scratch

USER nonroot

COPY --from=base / /