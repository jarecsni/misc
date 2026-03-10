# MCP Infrastructure Reference
*TextologyLabs / Layrz / Philos*

---

## Architecture Overview

```
Claude surfaces (claude.ai / Claude Code CLI / Xcode R2)
     │
     ▼ HTTPS
mcp.textologylabs.ai/<secret>/mcp
     │
     ▼
Nginx (SSL termination via Let's Encrypt)
     │
     ▼ HTTP localhost:8000
supergateway (Docker)
     │
     ▼ stdio
@modelcontextprotocol/server-memory
     │
     ▼ persists to
/opt/mcp/memory/data/memory.json
```

---

## Hetzner VPS — TextologyLabs-0

| Property | Value |
|---|---|
| Provider | Hetzner Cloud |
| Name | TextologyLabs-0 |
| Plan | CPX22 — 2 vCPU, 4GB RAM, 80GB NVMe |
| Location | Helsinki |
| OS | Ubuntu 24.04 LTS |
| IPv4 | 204.168.139.101 |
| Backups | Enabled (daily, 20% surcharge) |
| Cost | ~$10.79/month |

### SSH Access

```bash
ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101
```

SSH key: `~/.ssh/hetzner_ed25519` (public: `~/.ssh/hetzner_ed25519.pub`)

### Firewall (UFW)

Open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)

```bash
ufw status
```

### Installed Services

- Docker
- Nginx
- Certbot (Let's Encrypt)
- Node.js 22

---

## Memory MCP Server

### Files on Server

```
/opt/mcp/memory/
├── docker-compose.yml      — service definition
├── .secret-path            — secret URL token (never share or expose)
└── data/
    └── memory.json         — persistent graph data
```

### docker-compose.yml

```yaml
services:
  memory:
    image: node:22-alpine
    working_dir: /app
    command: sh -c "npx -y supergateway --port 8000 --outputTransport streamableHttp --cors --healthEndpoint /healthz --stdio 'MEMORY_FILE_PATH=/data/memory.json npx -y @modelcontextprotocol/server-memory'"
    ports:
      - "8000:8000"
    volumes:
      - ./data:/data
    restart: unless-stopped
    stop_grace_period: 10s
```

> **Important:** `MEMORY_FILE_PATH` must be inlined in the stdio command string — supergateway does not forward environment variables to the child process.

### Docker Commands

```bash
cd /opt/mcp/memory

# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# Logs
docker compose logs -f

# Check data file
ls -la data/
```

### Health Check

```bash
curl https://mcp.textologylabs.ai/healthz
# Expected: ok
```

### Test MCP Endpoint

```bash
curl -X POST https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
# Expected: SSE response with serverInfo
```

### Known Issue: npx Cache Corruption

Symptom: `ERR_MODULE_NOT_FOUND` for `completable.js` in logs. Child process crashes on every connection.

Fix:
```bash
cd /opt/mcp/memory
docker compose down
docker compose run --rm memory sh -c "rm -rf /root/.npm/_npx"
docker compose up -d
```

---

## DNS & Domains

**Registrar:** Namecheap — do not make DNS changes here.
**DNS Management:** Cloudflare — all DNS changes go here.

### Key DNS Records (textologylabs.ai)

| Type | Name | Value | Proxy | Notes |
|---|---|---|---|---|
| A | mcp | 204.168.139.101 | OFF (DNS only) | Points to Hetzner VPS. Must stay unproxied for Let's Encrypt. |

> **Critical:** Never enable Cloudflare proxy (orange cloud) on the `mcp` record — it will break SSL cert renewal.

### SSL Certificate

Issued by Let's Encrypt via Certbot. Auto-renews.

```bash
# Check cert status
certbot certificates

# Force renew
certbot renew
```

### Nginx Config Location

```
/etc/nginx/sites-available/mcp
```

Only the secret path returns a valid response. All other paths return 404.

---

## macOS Keychain (iMac)

MCP URLs and tokens are stored in macOS Keychain. Never hardcode them in config files or repos.

### Keychain Entries

| Service Name | Contains |
|---|---|
| `claude-mcp-memory-url` | Full MCP URL including secret path |
| `claude-mcp-github-token` | GitHub Personal Access Token |

### Useful Commands

```bash
# Read memory URL
security find-generic-password -s "claude-mcp-memory-url" -w

# Update memory URL — reads secret from server via SSH, stores in keychain
security add-generic-password -U -a "$USER" -s "claude-mcp-memory-url" \
  -w "$(ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101 \
  'echo https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp')"
```

---

## Cross-Surface Claude Integration

### Surface Summary

| Surface | Config Location | Notes |
|---|---|---|
| claude.ai | Settings → Connectors | Manual URL update required |
| Claude Code CLI | `~/.claude.json` | Managed via `claude mcp` commands |
| Xcode Agent (R2) | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` | Managed via `inject-mcps.sh` |

### Claude Code CLI

```bash
# List MCPs and check status
claude mcp list

# Re-add memory MCP (e.g. after URL rotation)
claude mcp remove memory --scope user
claude mcp add --transport http --scope user memory \
  "$(security find-generic-password -s claude-mcp-memory-url -w)"
```

### Xcode (R2) — inject-mcps.sh

Config template: `~/.xcode-behaviors/mcp-config.json`
Inject script: `~/.xcode-behaviors/inject-mcps.sh`
Backed up in: `~/dev/misc/xcode-behaviors/`

Template uses `__KEYCHAIN:service-name__` placeholders resolved at inject time:

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

## Global Steering

```
~/.claude/
├── CLAUDE.md              — startup sequence instruction
└── steering/
    └── memory.md          — memory graph protocol
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

**Notes:**
- Claude Code CLI honours this reliably and initialises automatically
- R2 (Xcode) reads the same file but may occasionally need a nudge
- claude.ai uses userPreferences instead — update manually when protocol changes

---

## Memory Graph Protocol

### Top-Level Nodes

| Node | Type | Purpose |
|---|---|---|
| `global` | namespace | Load every session |
| `projects` | namespace | Project entities (Philos, Fartybird, misc) |
| `topics` | namespace | Interest areas (NSAI, Spanish, etymology) |
| `TextologyLabs-0` | server | Hetzner VPS details |

### Usage Pattern

```
open_nodes(["global"])                       # always at session start
open_nodes(["projects", "Philos"])           # when working on Philos
open_nodes(["topics", "NSAI"])               # when discussing NSAI
search_nodes("query")                        # discovery
open_nodes(["EntityName"])                   # targeted retrieval
```

> **Never call `read_graph`** — reserved for admin/backup only.

---

## Rotating the Secret URL

If the secret URL is ever compromised:

**1. On the server — generate new token and update Nginx:**
```bash
# SSH in first
ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101

# Generate new token
openssl rand -hex 32 > /opt/mcp/memory/.secret-path

# Update Nginx config
SECRET=$(cat /opt/mcp/memory/.secret-path)
sed -i "s|location /[a-f0-9]*/mcp|location /${SECRET}/mcp|" /etc/nginx/sites-available/mcp
nginx -t && systemctl reload nginx
```

**2. On iMac — update keychain:**
```bash
security add-generic-password -U -a "$USER" -s "claude-mcp-memory-url" \
  -w "$(ssh -i ~/.ssh/hetzner_ed25519 root@204.168.139.101 \
  'echo https://mcp.textologylabs.ai/$(cat /opt/mcp/memory/.secret-path)/mcp')"
```

**3. Update Claude Code CLI:**
```bash
claude mcp remove memory --scope user
claude mcp add --transport http --scope user memory \
  "$(security find-generic-password -s claude-mcp-memory-url -w)"
```

**4. Re-inject Xcode:**
```bash
~/.xcode-behaviors/inject-mcps.sh --all
```

**5. Update claude.ai connector manually** in Settings → Connectors.

---

## Decommissioned

- **Railway MCP server** — replaced by Hetzner VPS
- **Cloudflare tunnel (mcp-memory)** — DNS Tunnel record deleted
- **Local Docker mcp-memory container** — shut down; `~/.server-memory/memory.json` kept as backup