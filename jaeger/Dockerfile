# Jaeger v2 for Railway.
#
# One layer on top of the published image: it adds the two configuration files
# the binary needs (`--config` is mandatory in v2) and nothing else. The image
# is near-distroless -- no shell, no package manager -- so everything here is a
# COPY, and the role is selected by the service's start command:
#
#   /cmd/jaeger/jaeger-linux --config /jaeger-railway/collector.yaml
#   /cmd/jaeger/jaeger-linux --config /jaeger-railway/query.yaml
#
# Pinned rather than floating because the collector and the query service must
# be the same build: they share one on-disk index schema in OpenSearch, and two
# services resolving `latest` at different moments can land on different ones.
FROM jaegertracing/jaeger:2.20.0

COPY jaeger/collector.yaml /jaeger-railway/collector.yaml
COPY jaeger/query.yaml     /jaeger-railway/query.yaml
COPY jaeger/sampling-strategies.json /jaeger-railway/sampling-strategies.json
