#!/bin/sh
# Basic-auth front door for the Jaeger query service.
#
# Jaeger's UI and query API ship with no authentication of any kind, so the
# query service takes no public domain and this gateway is the only thing
# Railway's edge routes to. Caddy wants a bcrypt hash and no Railway variable
# can compute one, so it is derived here, at boot, from the plaintext password.
set -eu

: "${PORT:=8080}"
: "${JAEGER_UI_USERNAME:=admin}"
: "${JAEGER_QUERY_UPSTREAM:=jaeger-query.railway.internal:16686}"

if [ -z "${JAEGER_UI_PASSWORD:-}" ]; then
	echo "FATAL: JAEGER_UI_PASSWORD is not set -- refusing to serve Jaeger unauthenticated." >&2
	exit 1
fi

# --plaintext is the only scriptable form: reading stdin works from a terminal
# only, and piping it returns an empty hash that fails caddy validate.
JAEGER_UI_PASSWORD_HASH="$(caddy hash-password --plaintext "$JAEGER_UI_PASSWORD")"
if [ -z "$JAEGER_UI_PASSWORD_HASH" ]; then
	echo "FATAL: could not hash JAEGER_UI_PASSWORD." >&2
	exit 1
fi

export PORT JAEGER_UI_USERNAME JAEGER_QUERY_UPSTREAM JAEGER_UI_PASSWORD_HASH
# The plaintext is not needed past this point and the app is a child process.
unset JAEGER_UI_PASSWORD

caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
echo "gateway: fronting ${JAEGER_QUERY_UPSTREAM} on :${PORT} as ${JAEGER_UI_USERNAME}"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
