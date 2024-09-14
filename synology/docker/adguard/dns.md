# DNS providers in use

## Upstream

```
# DNS-over-HTTPs
https://dns.cloudflare.com/dns-query
https://dns.quad9.net/dns-query
# DNS-over-TLS
tls://one.one.one.one
tls://dns.quad9.net
```

## Fallback

```
# Cloudflare Main
1.1.1.1
2606:4700:4700::1111
# Quad9 Main
9.9.9.9
2620:fe::fe
# Cloudflare Fallback
1.0.0.1
2606:4700:4700::1001
# Quad9 Fallback
149.112.112.112
2620:fe::fe:9
```

## Bootstrap

```
1.1.1.1
2606:4700:4700::1111
9.9.9.9
2620:fe::fe
1.0.0.1
2606:4700:4700::1001
149.112.112.112
2620:fe::9
```
