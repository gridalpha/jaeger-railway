#!/bin/sh
# Retention for Jaeger's date-stamped OpenSearch indices.
#
# Jaeger writes one index per day per type (jaeger-span-2026-09-02 and friends)
# and never deletes them, so a trace store left alone fills its volume and stops
# accepting spans. Upstream ships this as a cron job; Railway templates drop
# `cronSchedule`, so it is expressed here as a long-lived worker that sleeps
# between passes and is restarted forever by the platform.
#
# jaeger-archive-* is deliberately not matched: a trace someone archived from
# the UI is meant to outlive the retention window.
set -eu

: "${OPENSEARCH_URL:=http://opensearch.railway.internal:9200}"
: "${OPENSEARCH_USERNAME:=admin}"
: "${RETENTION_DAYS:=7}"
: "${CLEANUP_INTERVAL_SECONDS:=21600}"

if [ -z "${OPENSEARCH_PASSWORD:-}" ]; then
	echo "FATAL: OPENSEARCH_PASSWORD is not set." >&2
	exit 1
fi

PATTERNS="jaeger-span-*,jaeger-service-*,jaeger-dependencies-*,jaeger-sampling-*"

log() { echo "index-cleaner: $*"; }

log "retention ${RETENTION_DAYS}d, every ${CLEANUP_INTERVAL_SECONDS}s, against ${OPENSEARCH_URL}"

while true; do
	cutoff="$(date -u -d "@$(( $(date -u +%s) - RETENTION_DAYS * 86400 ))" +%Y-%m-%d)"

	indices="$(curl -sS --max-time 30 -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" \
		"${OPENSEARCH_URL}/_cat/indices/${PATTERNS}?h=index&format=text" 2>/dev/null || true)"

	if [ -z "$indices" ]; then
		log "nothing to consider yet (cutoff ${cutoff})"
	else
		deleted=0
		for index in $indices; do
			# Trailing YYYY-MM-DD; anything else is not a rotated index.
			day="$(printf '%s' "$index" | sed -n 's/.*-\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)$/\1/p')"
			[ -n "$day" ] || continue
			# ISO dates sort lexicographically, so a string compare is a date compare.
			[ "$day" \< "$cutoff" ] || continue
			if curl -sS --max-time 60 -o /dev/null -w '' -X DELETE \
				-u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" \
				"${OPENSEARCH_URL}/${index}"; then
				log "deleted ${index}"
				deleted=$((deleted + 1))
			else
				log "failed to delete ${index}"
			fi
		done
		log "pass complete, cutoff ${cutoff}, deleted ${deleted}"
	fi

	sleep "$CLEANUP_INTERVAL_SECONDS"
done
