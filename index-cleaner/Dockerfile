FROM alpine:3.22

RUN apk add --no-cache curl ca-certificates

COPY index-cleaner/cleaner.sh /usr/local/bin/jaeger-index-cleaner.sh
RUN chmod 0755 /usr/local/bin/jaeger-index-cleaner.sh \
 && sh -n /usr/local/bin/jaeger-index-cleaner.sh

USER nobody
ENTRYPOINT ["/usr/local/bin/jaeger-index-cleaner.sh"]
