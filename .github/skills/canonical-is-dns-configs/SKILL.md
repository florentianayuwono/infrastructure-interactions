---
name: canonical-is-dns-configs
description: Use when configuring new DNS zones, adding A/CNAME records, or modifying BIND configurations in the canonical-is-dns-configs repository
---

# Canonical IS DNS Configurations

## Overview

The canonical-is-dns-configs repository manages DNS zones and records for internal infrastructure using BIND9 configuration files. Changes require zone files (defining records) and BIND configuration (declaring zones).

## Repo Layout

```
canonical-is-dns-configs/
  zones/
    <zone-name>.zone    # DNS zone files with A/CNAME/NS/MX records
  named.conf.
    zones               # Zone declarations for BIND
    options             # Global BIND options
    forwarders          # Forwarder configuration
  overlays/
    <env>/              # Environment-specific overrides (ps5, ps7, etc.)
```

## Questions to Ask the User

### For a new DNS zone (`zones/<zone-name>.zone`)

1. **Zone name** — What is the domain? (e.g. `demo.local`, `services.internal`)
2. **TTL** — Default TTL for records (seconds, default: 604800 = 1 week)
3. **Primary NS** — Name server FQDN (e.g. `ns1.demo.local.`)
4. **Admin email** — Zone admin email address (dots for @, e.g. `admin.demo.local.`)
5. **Name servers** — Which hosts are NS for this zone?
6. **Records needed** — List all required records:
   - A records (hostname → IP)
   - CNAME records (alias → target)
   - NS records (subdomain delegation)
   - MX records (if mail server)

### For new DNS records in existing zone

1. **Target zone** — Which zone file to modify?
2. **Record type** — A, CNAME, NS, MX, TXT
3. **Hostname** — The left-hand side (e.g. `api`, `www`, `*.services`)
4. **Value** — The right-hand side (IP for A, FQDN for CNAME)
5. **TTL** — Override default TTL? (optional)

### For BIND configuration updates

1. **Zone type** — master, slave, or stub?
2. **Allow queries** — Source networks allowed to query this zone
3. **Forwarders** — External DNS servers for recursion?
4. **Zone file path** — Absolute path to zone file

## File Formats

### Zone File (zones/<name>.zone)

```zone
; BIND zone file for demo.local
; Auto-generated - DO NOT EDIT MANUALLY

$TTL    604800
@       IN      SOA     ns1.demo.local. admin.demo.local. (
                              2         ; Serial (YYYYMMDDNN format)
                         604800         ; Refresh (1 week)
                          86400         ; Retry (1 day)
                        2419200         ; Expire (4 weeks)
                         604800 )       ; Negative Cache TTL

; Name servers
@       IN      NS      ns1.demo.local.
ns1     IN      A       10.142.65.3

; Infrastructure hosts
proxy           IN      A       10.142.65.2
dns             IN      A       10.142.65.3
ingress         IN      A       10.142.65.4
monitoring      IN      A       10.142.65.5

; CNAME aliases
www             IN      CNAME   ingress.demo.local.
api             IN      CNAME   ingress.demo.local.

; Subdomain delegation
services        IN      NS      ns1.demo.local.

; Wildcard record
*.services      IN      CNAME   ingress.demo.local.
```

### BIND Zone Configuration (named.conf.zones)

```zone
// Main demo zone
zone "demo.local" {
    type master;
    file "/etc/bind/zones/demo.local.zone";
    allow-query { 10.142.0.0/16; 127.0.0.1; };
};

// Reverse zone for 10.142.65.x
zone "65.142.10.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.10.142.65";
    allow-query { 10.142.0.0/16; 127.0.0.1; };
};
```

### BIND Options (named.conf.options)

```zone
options {
    directory "/var/cache/bind";
    
    // Forwarders
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    // Allow queries from internal networks
    allow-query { 10.0.0.0/8; 172.16.0.0/12; 192.168.0.0/16; 127.0.0.1; };
    
    // DNSSEC
    dnssec-validation auto;
    
    // Performance
    max-cache-size 256m;
};
```

## Record Type Examples

| Type | Purpose | Example |
|------|---------|---------|
| A | Host ⇒ IP | `web IN A 10.0.0.1` |
| CNAME | Alias ⇒ Host | `www IN CNAME web.demo.local.` |
| NS | Delegation | `sub IN NS ns1.demo.local.` |
| MX | Mail server | `@ IN MX 10 mail.demo.local.` |
| TXT | Text record | `@ IN TXT "v=spf1 include:_spf.google.com ~all"` |
| PTR | Reverse lookup | `3 IN PTR dns.demo.local.` |

## Serial Number Format

Use `YYYYMMDDNN` format where:
- `YYYYMMDD` = Date of change
- `NN` = Revision number for that day (01, 02, ...)

Examples:
- `2026051301` = First change on May 13, 2026
- `2026051302` = Second change on May 13, 2026

## Common Mistakes

- **Missing trailing dots** — FQDNs in zone files must end with `.` (e.g. `ns1.demo.local.`)
- **Wrong serial format** — Always use YYYYMMDDNN, increment when changing zone
- **Zone file not declared** — Must add zone to `named.conf.zones` for BIND to serve it
- **CNAME conflicts** — Can't have CNAME with other records for same name
- **Reverse zone mismatch** — PTR records must match the in-addr.arpa zone declaration

## Common Patterns

### Wildcard services
```zone
*.api         IN      CNAME   api.demo.local.
```

### Subdomain delegation
```zone
services      IN      NS      ns1.services.demo.local.
ns1.services  IN      A       10.142.65.10
```

### Multiple IPs for load balancing
```zone
web           IN      A       10.142.65.10
web           IN      A       10.142.65.11
web           IN      A       10.142.65.12
```
