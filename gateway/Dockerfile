FROM caddy:2-alpine

COPY gateway/Caddyfile /etc/caddy/Caddyfile
COPY gateway/entrypoint.sh /usr/local/bin/gateway-entrypoint.sh

# A typo here should fail the build, not crash-loop a container whose log shows
# nothing but an exit code.
RUN chmod 0755 /usr/local/bin/gateway-entrypoint.sh \
 && sh -n /usr/local/bin/gateway-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/gateway-entrypoint.sh"]
