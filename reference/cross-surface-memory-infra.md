# Cross-Surface Claude Memory Infrastructure
## AI Context Document — Textology Labs
**Last updated:** 2026-03-08  
**Status:** Live (Kiro CLAUDE.md steering pending)

---

## Overview

This document describes the infrastructure built to establish a shared knowledge graph across all three Claude surfaces used in Textology Labs development:

| Surface | Config Location | MCP Transport |
|---|---|---|
| claude.ai chat | Anthropic-hosted connector | HTTPS via Cloudflare Tunnel |
| Claude Code CLI | `~/.claude.json` | stdio |
| Xcode 26.3 Agent | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` | stdio (injected) |

All three surfaces read from and write to the same knowledge graph at `~/.server-memory/memory.json`.

---

## Problem Solved

Claude surfaces are context silos by default:
- claude.ai has Anthropic-hosted native memory (~30 entries, 500 chars each, chat-only)
- Claude Code CLI reads `~/.claude.json` and CLAUDE.md files
- Xcode Agent has its own isolated config, sandboxed from the shell environment

No native bridge exists between them. This infrastructure provides one.

---

## Memory Layer Architecture

Three distinct layers, each with a different role:

### Layer 1: Native Memory (claude.ai only)
- Anthropic-hosted, auto-injected into chat context
- ~30 entries max, 500 chars each
- Use for: personal preferences, identity, tone, working style
- Not accessible by Claude Code or Xcode

### Layer 2: server-memory Knowledge Graph (all surfaces)
- `@modelcontextprotocol/server-memory` — official Anthropic MCP package
- Structured entities, relations, observations
- File: `~/.server-memory/memory.json`
- Use for: project decisions, architecture, cross-surface state, Textology Labs context
- Queryable and writable from any surface

### Layer 3: CLAUDE.md Steering (Claude Code only)
- Filesystem-based markdown files
- `~/.claude/CLAUDE.md` — global steering
- `.claude/CLAUDE.md` — per-project steering
- Use for: Kiro-style task instructions, coding conventions, project-specific context
- **[KIRO IMPLEMENTATION PENDING — see section below]**

---

## Infrastructure Components

### 1. DNS — Cloudflare

Both `textologylabs.ai` and `textologylabs.com` migrated from Namecheap DNS to Cloudflare (free tier). Domains remain registered at Namecheap; Cloudflare manages DNS only.

Nameservers:
- `darl.ns.cloudflare.com`
- `kami.ns.cloudflare.com`

### 2. MCP Memory Server (Docker)

Location: `~/docker/mcp-memory/`

**Dockerfile:**
```dockerfile
FROM node:20-alpine
RUN npm install -g @modelcontextprotocol/server-memory mcp-proxy
ENV MEMORY_FILE_PATH=/data/memory.json
EXPOSE 8000
CMD ["mcp-proxy", "--port", "8000", "--", "npx", "-y", "@modelcontextprotocol/server-memory"]
```

**docker-compose.yml:**
```yaml
services:
  mcp-memory:
    build: .
    container_name: mcp-memory
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ~/.server-memory:/data
    environment:
      - MEMORY_FILE_PATH=/data/memory.json
```

The container bridges stdio (used by Claude Code/Xcode) to HTTP (used by claude.ai via tunnel).

Endpoints:
- `http://localhost:8000/sse` — SSE transport (local)
- `http://localhost:8000/mcp` — Streamable HTTP (used by claude.ai)

Note: `doobidoo/mcp-memory-service` was attempted first but failed with `ModuleNotFoundError: No module named 'aiosqlite'`. Custom Dockerfile was required.

### 3. Cloudflare Tunnel

Exposes the local Docker container to claude.ai over HTTPS.

- **Tunnel name:** `mcp-memory`
- **Tunnel ID:** `20243a7b-3fe2-4c81-8e10-d91c96419038`
- **Credentials:** `~/.cloudflared/20243a7b-3fe2-4c81-8e10-d91c96419038.json`
- **Public URL:** `https://mcp-memory.textologylabs.ai`

**Config** (`~/.cloudflared/config.yml`):
```yaml
tunnel: 20243a7b-3fe2-4c81-8e10-d91c96419038
credentials-file: /Users/johnny/.cloudflared/20243a7b-3fe2-4c81-8e10-d91c96419038.json
ingress:
  - hostname: mcp-memory.textologylabs.ai
    service: http://localhost:8000
  - service: http_status:404
```

**Auto-start LaunchAgent** (`~/Library/LaunchAgents/homebrew.mxcl.cloudflared.plist`):
```xml
<key>ProgramArguments</key>
<array>
  <string>/opt/homebrew/opt/cloudflared/bin/cloudflared</string>
  <string>tunnel</string>
  <string>run</string>
  <string>mcp-memory</string>
</array>
```

Note: `sudo cloudflared service install` and `brew services start cloudflared` both failed with wrong args in plist. Manual LaunchAgent plist creation was required. Loaded via `launchctl load ~/Library/LaunchAgents/homebrew.mxcl.cloudflared.plist`.

### 4. claude.ai Custom Connector

- **Name:** Server Memory
- **URL:** `https://mcp-memory.textologylabs.ai/mcp`
- **Auth:** None
- **All 9 tools set to Allow** (not "Needs approval")

Available tools: `add_observations`, `create_entities`, `create_relations`, `delete_entities`, `delete_observations`, `delete_relations`, `open_nodes`, `read_graph`, `search_nodes`

### 5. Claude Code CLI Config

Entry in `~/.claude.json`:
```json
"memory": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "env": {
    "MEMORY_FILE_PATH": "/Users/johnny/.server-memory/memory.json"
  }
}
```

Added via:
```bash
claude mcp add --scope user memory -e MEMORY_FILE_PATH=/Users/johnny/.server-memory/memory.json -- npx -y @modelcontextprotocol/server-memory
```

### 6. Xcode Agent Injection

Xcode Agent runs in a sandboxed environment that:
- Does not inherit the shell
- Does not read `~/.claude.json`
- Cannot use nvm-managed Node — requires Homebrew Node at absolute path

Xcode Agent config location:
`~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json`

MCP definitions are managed via `~/.xcode-behaviors/mcp-config.json` and injected with a script.

**`~/.xcode-behaviors/mcp-config.json`:**
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
    "command": "/opt/homebrew/bin/npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"],
    "env": {
      "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "MEMORY_FILE_PATH": "/Users/johnny/.server-memory/memory.json"
    }
  }
}
```

**`~/.xcode-behaviors/inject-mcps.sh`** supports:
- `inject-mcps.sh <project-path>` — inject into a single project, creating entry if missing
- `inject-mcps.sh --all` — inject into all projects in the config (retrofit)
- Resolves `__KEYCHAIN:service-name__` placeholders at runtime via `security find-generic-password`

Scripts and config backed up in `~/dev/misc/xcode-behaviors/`.

---

## Key File Locations

| File | Purpose |
|---|---|
| `~/.server-memory/memory.json` | The shared knowledge graph |
| `~/docker/mcp-memory/` | Docker container source |
| `~/.cloudflared/config.yml` | Cloudflare tunnel config |
| `~/Library/LaunchAgents/homebrew.mxcl.cloudflared.plist` | Tunnel auto-start |
| `~/.claude.json` | Claude Code CLI MCP config |
| `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` | Xcode Agent MCP config |
| `~/.xcode-behaviors/mcp-config.json` | MCP definitions (source of truth) |
| `~/.xcode-behaviors/inject-mcps.sh` | Xcode MCP injection script |

---

## Useful Commands

```bash
# Check Docker container
docker ps | grep mcp-memory
docker logs mcp-memory

# Test local endpoint
curl http://localhost:8000/mcp

# Test tunnel
curl https://mcp-memory.textologylabs.ai/mcp

# Tunnel status
launchctl list | grep cloudflared

# View memory graph
cat ~/.server-memory/memory.json

# Claude Code MCP status
claude /mcp

# Inject MCPs into all Xcode projects
~/.xcode-behaviors/inject-mcps.sh --all

# Inject into a specific project
~/.xcode-behaviors/inject-mcps.sh /Users/johnny/dev/ProjectName
```

---

## [KIRO-STYLE CLAUDE.md STEERING — PENDING]

The third context layer — CLAUDE.md-based steering — has not yet been implemented. This will follow the Kiro pattern of structured markdown files that provide Claude Code with persistent project context, coding conventions, and task scaffolding.

Planned structure:
- `~/.claude/CLAUDE.md` — global identity, preferences, tools, cross-project context
- Per-project `.claude/CLAUDE.md` — architecture decisions, conventions, active tasks

This section will be updated once implemented. The Hashnode article covering this full setup will be written after Kiro steering is in place.

---

## Verification Checklist

- [x] Docker container running (`docker ps | grep mcp-memory`)
- [x] Cloudflare tunnel active (`launchctl list | grep cloudflared`)
- [x] claude.ai connector responding (`read_graph` returns Philos entity)
- [x] Claude Code CLI memory connected (`/mcp` shows `memory · connected`)
- [x] Xcode Agent memory injected (fartybird + Philos configs verified)
- [x] Xcode Agent memory confirmed working (Cooper confirmed 3 MCPs)
- [ ] CLAUDE.md global steering implemented
- [ ] Knowledge graph seeded (Johnny, TextologyLabs, Layrz, Philos architecture)
