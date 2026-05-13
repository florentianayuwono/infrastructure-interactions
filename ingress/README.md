# Ingress (HAProxy)

Imitates ps7 ingress patterns with HAProxy routing to backend services.

## Files

- `haproxy.cfg` — HAProxy configuration with SSL and backends
- `setup-ingress.sh` — Automated install script

## ps7 Patterns Imitated

- HTTP → HTTPS redirect
- SSL termination
- Backend health checks
- Multiple service routes
- Connection limits and timeouts
