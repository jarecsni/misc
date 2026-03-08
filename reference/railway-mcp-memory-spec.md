# Spec: MCP Memory Server — Railway Deployment

## Objective

Create an `mcp/` subproject inside the `misc` repo and deploy it to Railway as a running Docker service. Stop after successful deployment. DNS, config migration, and decommissioning of the existing local Docker + Cloudflare Tunnel setup are out of scope.

## Context

The existing infrastructure (documented in `reference/cross-surface-memory-infra.md`) runs `@modelcontextprotocol/server-memory` in a local Docker container, exposed to claude.ai via a Cloudflare Tunnel. This spec moves the server to Railway so it's always-on without depending on the local machine.

## Constraints

- Work only inside `~/dev/misc/mcp/`
- Do not modify any files outside this directory (no `~/.claude.json`, no `~/.xcode-behaviors/`, no Cloudflare config)
- Stop after `railway up` succeeds and the service responds to a health check
- Commit all created files to the `misc` repo

## Tasks

### Task 1: Create project structure

```
mkdir -p ~/dev/misc/mcp
```

### Task 2: Create Dockerfile

`~/dev/misc/mcp/Dockerfile`

```
FROM node:20-alpine

RUN npm install -g @modelcontextprotocol/server-memory mcp-proxy

ENV MEMORY_FILE_PATH=/data/memory.json

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:8000/mcp || exit 1

CMD ["mcp-proxy", "--port", "8000", "--allow-origin", "*", \
     "--", "npx", "-y", "@modelcontextprotocol/server-memory"]
```

Notes on the Dockerfile:
- `mcp-proxy` and `@modelcontextprotocol/server-memory` are both installed globally at build time. The `npx -y` in CMD will resolve the already-installed global package — it won't re-download. This is the pattern from the existing working local Docker setup (see reference doc), so we're keeping it rather than inventing a new invocation.
- `HEALTHCHECK` gives Railway (and us) a real liveness signal instead of just "process is running".
- `/data/` is the volume mount point. Without a persistent volume attached, memory resets on redeploy — that's expected and fine for the initial deployment. Volume attachment is a post-deploy manual step.

### Task 3: Create railway.json

`~/dev/misc/mcp/railway.json`

```
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "numReplicas": 1,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

### Task 4: Create .railwayignore

`~/dev/misc/mcp/.railwayignore`

```
README.md
.git
```

### Task 5: Create .dockerignore

`~/dev/misc/mcp/.dockerignore`

```
README.md
.git
.railwayignore
railway.json
```

Keeps the build context clean. Railway uses `.railwayignore` for its upload; Docker uses `.dockerignore` for the build. Both should exist.

### Task 6: Create README.md

`~/dev/misc/mcp/README.md`

```
# MCP Memory Server — Railway Deployment

Deploys `@modelcontextprotocol/server-memory` via `mcp-proxy` to Railway.
Provides a shared knowledge graph for all Claude surfaces.

## Endpoints

- `/mcp` — Streamable HTTP (used by claude.ai and HTTP-mode clients)
- `/sse` — SSE transport

## Post-deploy steps (manual, separate from this spec)

1. Attach persistent volume in Railway dashboard → mount path `/data`
2. Add custom domain `mcp-memory.textologylabs.ai` in Railway dashboard
3. Update Cloudflare DNS CNAME to point to Railway domain
4. Migrate `~/.server-memory/memory.json` to Railway volume
5. Update Claude Code CLI and Xcode configs to use HTTP transport
6. Decommission local Docker container and Cloudflare Tunnel
```

### Task 7: Deploy to Railway

This task requires human interaction — `railway link` is a TUI command.

```
cd ~/dev/misc/mcp

# Interactive: link to Railway, create project "mcp-memory"
railway link

# Deploy
railway up
```

After `railway up` completes, verify:
1. Railway dashboard shows service as "running"
2. Health check is passing (green in dashboard)
3. `curl <railway-url>/mcp` returns a response

### Task 8: Commit to misc repo

```
cd ~/dev/misc
git add mcp/
git commit -m "🚀 add Railway MCP memory server deployment"
git push
```

## Stopping Point

Stop here. The following are explicitly out of scope for this spec:
- Persistent volume attachment
- DNS changes (Cloudflare CNAME)
- Memory data migration
- Claude config updates (`~/.claude.json`, Xcode agent config)
- Decommissioning local Docker + Cloudflare Tunnel

## Definition of Done

- [ ] `~/dev/misc/mcp/` exists with 5 files (Dockerfile, railway.json, .railwayignore, .dockerignore, README.md)
- [ ] `railway up` completed successfully
- [ ] Service running in Railway dashboard with passing health check
- [ ] `curl <railway-url>/mcp` returns a response
- [ ] Committed and pushed to misc repo
