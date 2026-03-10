# TextologyLabs Infrastructure Reference

## Overview

This document covers the full infrastructure stack for TextologyLabs / Layrz / Philos, including DNS, VPS, MCP memory server, and cross-surface Claude integration.

---

## DNS & Domains

### Registrar: Namecheap
Domains registered here but DNS is managed entirely via Cloudflare. Make all DNS changes in Cloudflare, not Namecheap.

### DNS: Cloudflare
Domains: `textologylabs.com`, `textologylabs.ai`

Key DNS records:
| Type | Name | Value | Notes |
|------|------|-------|-------|
| A | mcp | 204.168.139.101 | Points to Hetzner VPS. Proxy OFF (DNS only) |
| A | textologylabs.ai | 192.64.119.183 | Proxied |

> **Important:** The `mcp` A record must stay unproxied (grey cloud) — Let's Encrypt cert renewal requires direct connection to the server.

---

## VPS: Hetzner Cloud

**Server:** TextologyLabs-0
**Plan:** CPX22 — 2 vCPU, 4GB RAM, 80GB NVMe SSD
**Location:** Helsinki
**OS:** Ubuntu 24.04 LTS
**IP:** 204.168.139.101
**Backups:** Enabled (daily, 20% extra cost)
**Monthly cost:** ~$10.79 (server + backup + IPv4)

### SSH Access

```bash
ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101
```

SSH key stored at: `~/.ssh/hetzner_ed25519`
Public key at: `~/.ssh/hetzner_ed25519.pub`

### Firewall (UFW)
Ports open: 22 (SSH), 80 (HTTP), 443 (HTTPS)

```bash
ufw status
```

### Installed Services
- Docker
- Nginx (reverse proxy + SSL termination)
- Certbot (Let's Encrypt SSL)
- Node.js 22

---

## MCP Memory Server

### Architecture
```
Claude surfaces
     │
     ▼ HTTPS
mcp.textologylabs.ai/<secret>/mcp
     │
     ▼
Nginx (SSL termination)
     │
     ▼ HTTP
localhost:8000
     │
     ▼
Docker: supergateway wrapping @modelcontextprotocol/server-memory
```

### Files on Server
```
/opt/mcp/memory/
├── docker-compose.yml    — service definition
├── .secret-path          — the secret URL token (never share)
└── data/                 — persistent memory graph JSON
```

### Docker Compose
```bash
cd /opt/mcp/memory

# Start
docker compose up -d

# Logs
docker compose logs -f

# Restart
docker compose restart

# Stop
docker compose down
```

### Nginx Config
```
/etc/nginx/sites-available/mcp
```

The MCP endpoint is only accessible at the secret path. All other requests return 404.

### SSL Certificate
Issued by Let's Encrypt via Certbot. Auto-renews.

```bash
# Check cert expiry
certbot certificates

# Force renew
certbot renew
```

### Retrieving the Secret URL (from iMac)
The secret token lives on the server and is never stored in plaintext on the iMac. To retrieve the full MCP URL:

```bash
ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101 \
  'echo https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp'
```

---

## macOS Keychain (iMac)

MCP URLs and tokens are stored in macOS Keychain — never hardcoded in config files or repos.

### Keychain Entries

| Service name | Contains |
|---|---|
| `claude-mcp-memory-url` | Full MCP URL including secret path |
| `claude-mcp-github-token` | GitHub Personal Access Token |

### Useful Commands

```bash
# Read a keychain entry
security find-generic-password -s "claude-mcp-memory-url" -w

# Add or update a keychain entry
security add-generic-password -U -a "$USER" -s "claude-mcp-memory-url" -w "<value>"

# Update memory URL from server (reads secret via SSH, stores in keychain)
security add-generic-password -U -a "$USER" -s "claude-mcp-memory-url" \
  -w "$(ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101 \
  'echo https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp')"
```

---

## Cross-Surface Claude MCP Integration

### Surfaces & MCP Config

| Surface | How MCP is configured |
|---|---|
| claude.ai | Connector URL set manually in Settings → Connectors |
| Claude Code CLI | `~/.claude.json` via `claude mcp add` |
| Xcode Agent (R2) | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` via `inject-mcps.sh` |

### Claude Code CLI

```bash
# List MCPs
claude mcp list

# Re-add memory MCP (e.g. after URL rotation)
claude mcp remove memory --scope user
claude mcp add --transport http --scope user memory \
  "$(security find-generic-password -s claude-mcp-memory-url -w)"
```

### Xcode (R2) — inject-mcps.sh

MCP config template: `~/.xcode-behaviors/mcp-config.json`
Inject script: `~/.xcode-behaviors/inject-mcps.sh`
Both backed up in: `~/dev/misc/xcode-behaviors/`

The template uses `__KEYCHAIN:service-name__` placeholders that are resolved at inject time:

```json
{
  "github": {
    "command": "/opt/homebrew/bin/npx",
    "args": ["-y", "@modelcontextprotocol/server-github"],
    "env": {
      "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "GITHUB_PERSONAL_ACCESS_TOKEN": "__KEYCHAIN:claude-mcp-github-token__"
    }
  },
  "memory": {
    "type": "http",
    "url": "__KEYCHAIN:claude-mcp-memory-url__"
  }
}
```

```bash
# Inject into all Xcode projects
~/.xcode-behaviors/inject-mcps.sh --all

# Inject into a specific project
~/.xcode-behaviors/inject-mcps.sh /path/to/project
```

---

## Global Steering (Claude Code & R2)

```
~/.claude/
├── CLAUDE.md              — instructs agent to read steering dir at session start
└── steering/
    └── memory.md          — memory graph protocol (open_nodes etc.)
```

### CLAUDE.md Content
```
IMPORTANT: At the start of every session, before responding to anything, follow this startup sequence exactly:

1. Read all files in ~/.claude/steering/ (NOT the project-level .claude/steering/ — the global one at ~/.claude/steering/)
2. Announce: "✓ Global steering loaded"
3. EXECUTE every instruction found in those files as if they were direct commands from the user
4. Announce: "✓ Startup complete"

Only then respond to the user.
```

### Notes
- Claude Code CLI honours this reliably
- R2 (Xcode) reads the same `~/.claude/CLAUDE.md` but may occasionally need a nudge
- claude.ai uses userPreferences instead (manual sync when protocol changes)

---

## Memory Graph Protocol

Top-level nodes:
- `global` — load at every session start
- `projects` — namespace for project entities (Philos, Fartybird, misc)
- `topics` — namespace for ongoing interests (NSAI, Spanish, etymology, e-ink)
- `TextologyLabs-0` — this server

```
open_nodes(["global"])                          # always
open_nodes(["projects", "Philos"])              # when working on Philos
open_nodes(["topics", "NSAI"])                  # when discussing NSAI
search_nodes("query")                           # discovery
```

Never call `read_graph` — reserved for admin/backup only.

---

## Rotating the MCP Secret URL

If the secret URL is ever compromised:

1. **On the server:** generate a new token and update Nginx config
```bash
# On server
openssl rand -hex 32 > /opt/mcp/memory/.secret-path
SECRET=$(cat /opt/mcp/memory/.secret-path)
sed -i "s|location /[a-f0-9]*/mcp|location /${SECRET}/mcp|" /etc/nginx/sites-available/mcp
nginx -t && systemctl reload nginx
```

2. **On iMac:** update keychain
```bash
security add-generic-password -U -a "$USER" -s "claude-mcp-memory-url" \
  -w "$(ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101 \
  'echo https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp')"
```

3. Update Claude Code CLI and re-run inject script (see above)
4. Update claude.ai connector URL manually in Settings

---

## Decommissioned

- **Railway MCP server** — replaced by Hetzner VPS
- **Cloudflare tunnel (mcp-memory)** — DNS record deleted, tunnel decommissioned
- **Local Docker mcp-memory container** — shut down, `memory.json` kept at `~/.server-memory/memory.json` as backup