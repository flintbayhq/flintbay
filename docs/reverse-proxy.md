# Reverse Proxy Setup (HTTPS)

Run RCH behind a reverse proxy with TLS termination. Covers Caddy, Nginx, and Traefik.

## RCH Environment Variables

Set the externally reachable origin. RCH derives credentialed CORS, secure
cookies, and MCP metadata from this single value:

```yaml
environment:
  RCH_PUBLIC_URL: "https://rch.example.com"
  RCH_TRUSTED_PROXIES: "172.16.0.0/12"  # Docker network CIDR
```

Use `RCH_CORS_ORIGINS` or `RCH_COOKIE_SECURE` only when the proxy topology
requires an explicit override.

## Important: Live video bypasses the proxy

Everything HTTP — UI, API, WebSocket, MCP, and the LL-HLS video fallback — goes
through your proxy on `19580`. WebRTC live video does not: ICE is not HTTP and
cannot be reverse-proxied. Publish the media port on the RCH container itself
and open it in the firewall or security group:

```yaml
  rch:
    image: ghcr.io/kwaadx/rch:latest
    ports:
      - "8189:8189/udp"   # not proxied — direct to the container
      - "8189:8189/tcp"
```

The gateway derives its ICE host from `RCH_PUBLIC_URL`, so a proxy that
terminates TLS for `rch.example.com` needs no media-specific configuration.
Only when the browser reaches media through a different address — a separate
media DNS name, or a NAT address the origin does not resolve to — set
`RCH_MEDIA_WEBRTC_HOST` to that address.

Skipping this is a supported degradation, not a failure: video falls back to
LL-HLS through the proxy with about a second more latency. Tunnels that carry
only HTTP, including Cloudflare Tunnel, always take that fallback path.

## Important: WebSocket Support

RCH uses WebSocket for real-time data. Your proxy **must** support WebSocket upgrades on all paths. The key headers:

```
Upgrade: websocket
Connection: Upgrade
```

---

## Caddy (Recommended)

Caddy handles TLS certificates automatically via Let's Encrypt.

### docker-compose.yml

```yaml
services:
  caddy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    restart: unless-stopped

  rch:
    image: ghcr.io/kwaadx/rch:latest
    environment:
      RCH_PUBLIC_URL: "https://rch.example.com"
      RCH_TRUSTED_PROXIES: "172.16.0.0/12"
    volumes:
      - rch_data:/var/lib/rch
    restart: unless-stopped

volumes:
  rch_data:
  caddy_data:
```

### Caddyfile

```
rch.example.com {
    reverse_proxy rch:19580
}
```

That's it. Caddy auto-provisions TLS, handles WebSocket upgrades, and sets proper headers.

---

## Nginx

### docker-compose.yml

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/rch.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    restart: unless-stopped

  rch:
    image: ghcr.io/kwaadx/rch:latest
    environment:
      RCH_PUBLIC_URL: "https://rch.example.com"
      RCH_TRUSTED_PROXIES: "172.16.0.0/12"
    volumes:
      - rch_data:/var/lib/rch
    restart: unless-stopped

volumes:
  rch_data:
```

### nginx.conf

```nginx
upstream rch_backend {
    server rch:19580;
}

server {
    listen 80;
    server_name rch.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name rch.example.com;

    ssl_certificate     /etc/letsencrypt/live/rch.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rch.example.com/privkey.pem;

    # WebSocket support
    location / {
        proxy_pass http://rch_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for WebSocket (keep alive)
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

### Get certificates with certbot:

```bash
certbot certonly --standalone -d rch.example.com
```

---

## Traefik

### docker-compose.yml

```yaml
services:
  traefik:
    image: traefik:v3
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_certs:/letsencrypt
    restart: unless-stopped

  rch:
    image: ghcr.io/kwaadx/rch:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rch.rule=Host(`rch.example.com`)"
      - "traefik.http.routers.rch.tls.certresolver=letsencrypt"
      - "traefik.http.services.rch.loadbalancer.server.port=19580"
    environment:
      RCH_PUBLIC_URL: "https://rch.example.com"
      RCH_TRUSTED_PROXIES: "172.16.0.0/12"
    volumes:
      - rch_data:/var/lib/rch
    restart: unless-stopped

volumes:
  rch_data:
  traefik_certs:
```

Traefik handles WebSocket upgrades automatically — no extra config needed.

---

## Cloudflare Tunnel (No Port Forwarding)

If you can't open ports (NAT, ISP restrictions):

```bash
# Install cloudflared
cloudflared tunnel create rch
cloudflared tunnel route dns rch rch.example.com
cloudflared tunnel run --url http://localhost:19580 rch
```

Set in RCH:
```yaml
RCH_PUBLIC_URL: "https://rch.example.com"
```

> ⚠️ Cloudflare has a 100-second timeout on WebSocket idle connections. RCH's heartbeat (every 1s) keeps the connection alive, so this shouldn't be an issue.

---

## Verification

After setup, verify everything works:

```bash
# Check HTTPS
curl -I https://rch.example.com

# Check WebSocket upgrade
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://rch.example.com/api/ws
```

Expected: `101 Switching Protocols`

## Troubleshooting

| Problem | Fix |
|---------|-----|
| WebSocket disconnects | Increase proxy timeout (`proxy_read_timeout 86400s` in Nginx) |
| Login redirect loop | Set `RCH_PUBLIC_URL` to the exact external HTTPS origin |
| 502 Bad Gateway | RCH container not running or wrong service name in proxy config |
| Mixed content warnings | Ensure all traffic uses the `RCH_PUBLIC_URL` HTTPS origin |
| Camera video plays but lags about a second | WebRTC could not connect and LL-HLS took over; publish `8189/udp` and `8189/tcp` and open them upstream |
| Camera video never starts | Check the Source in Connection Studio; the media port only affects which transport is used, not authorization |
| CSRF token mismatch | Verify `RCH_PUBLIC_URL`; override cookie domain/SameSite only when required |
