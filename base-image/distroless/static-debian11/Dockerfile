FROM gcr.io/distroless/static-debian11:debug-nonroot as os


FROM gcr.io/distroless/static-debian11:nonroot as base

USER root
COPY --from=os /busybox /

FROM scratch

COPY --from=base / /

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/busybox
USER nonroot

ENTRYPOINT ["sh"]