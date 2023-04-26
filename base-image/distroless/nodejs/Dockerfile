FROM 2030047311/nodejs20-debian11:debug as os
# FROM gcr.io/distroless/nodejs20-debian11:debug as os


FROM 2030047311/nodejs20-debian11:nonroot as base
# FROM gcr.io/distroless/nodejs20-debian11:nonroot as base

USER root
COPY --from=os /busybox/sh /bin/sh
COPY --from=os /busybox/ /busybox/

#ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/busybox

RUN /busybox/rm -rf /usr/share/gcc /usr/share/gdb /busybox /bin/sh

FROM scratch

USER nonroot

COPY --from=base / /