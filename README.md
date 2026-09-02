# jaeger-railway

Deployment sources for [Jaeger](https://www.jaegertracing.io/) on
[Railway](https://railway.com) — the CNCF distributed tracing platform, in
upstream's *direct to storage* production shape: a collector role and a query
role built from one image, an OpenSearch backend, a basic-auth gateway in front
of the UI, and a retention worker.

| Directory | Service | What it builds |
|---|---|---|
| `jaeger/` | `jaeger-collector`, `jaeger-query` | `jaegertracing/jaeger:2.20.0` plus the two role configs |
| `gateway/` | `gateway` | `caddy:2-alpine` with HTTP basic auth in front of the query UI |
| `index-cleaner/` | `jaeger-index-cleaner` | Alpine worker that drops span indices past the retention window |

The OpenSearch node itself is built from
[`gridalpha/opensearch-railway`](https://github.com/gridalpha/opensearch-railway).

## Why each piece exists

- **Jaeger v2 requires `--config`.** There is no all-env-var mode, and the file
  is multi-line YAML, which a Railway template would replace with placeholder
  text if it were carried in a variable. So the configs are committed here and
  read every deployment-specific value from the environment with
  `${env:VAR}` — no secret is written to disk and no hostname is hard-coded.
- **The OTLP endpoint is public, so it authenticates.** Both OTLP protocols sit
  behind the collector's `basicauth` extension; the credential is expanded from
  the environment at start.
- **Jaeger's UI has no authentication of any kind.** The query service therefore
  takes no public domain: `gateway/` is the only thing Railway's edge routes to,
  and Caddy needs a bcrypt hash no Railway variable can compute, so the
  entrypoint derives it at boot from the plaintext password.
- **Retention is not optional for a trace store.** Jaeger creates one index per
  day and deletes none; upstream ships a cron job, and Railway templates drop
  `cronSchedule`, so `index-cleaner/` is the same work as a sleeping worker.

## Variables

`jaeger-collector` and `jaeger-query`

| Variable | Default | Notes |
|---|---|---|
| `OPENSEARCH_URL` | `http://opensearch.railway.internal:9200` | private only |
| `OPENSEARCH_USERNAME` | `admin` | |
| `OPENSEARCH_PASSWORD` | — | required |
| `JAEGER_LOG_LEVEL` | `info` | |
| `OTLP_USERNAME` / `OTLP_PASSWORD` | `otlp` / — | collector only; guards both OTLP protocols |
| `JAEGER_INITIAL_SAMPLING_PROBABILITY` | `0.1` | collector only, adaptive sampling seed |
| `JAEGER_MAX_CLOCK_SKEW_ADJUST` | `0s` | query only |

`gateway`

| Variable | Default | Notes |
|---|---|---|
| `JAEGER_UI_USERNAME` | `admin` | |
| `JAEGER_UI_PASSWORD` | — | required; the entrypoint exits rather than serve Jaeger unauthenticated |
| `JAEGER_QUERY_UPSTREAM` | `jaeger-query.railway.internal:16686` | |

`jaeger-index-cleaner`

| Variable | Default | Notes |
|---|---|---|
| `RETENTION_DAYS` | `7` | `jaeger-archive-*` is never touched |
| `CLEANUP_INTERVAL_SECONDS` | `21600` | |

## Start commands

The Jaeger image is near-distroless with an `ENTRYPOINT` and no `CMD`, so each
role names the binary and its config explicitly:

```
/cmd/jaeger/jaeger-linux --config /jaeger-railway/collector.yaml
/cmd/jaeger/jaeger-linux --config /jaeger-railway/query.yaml
```

## Licence

Apache-2.0, matching upstream Jaeger.
