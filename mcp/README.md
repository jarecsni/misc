# MCP Memory Server — Railway Deployment

Deploys `@modelcontextprotocol/server-memory` via `mcp-proxy` to Railway.
Provides a shared knowledge graph for all Claude surfaces.

## Endpoints

- `/mcp` — Streamable HTTP (used by claude.ai and HTTP-mode clients)
- `/healthz` — Health check

## Post-deploy steps (manual, separate from this spec)

1. Attach persistent volume in Railway dashboard → mount path `/data`
2. Add custom domain `mcp-memory.textologylabs.ai` in Railway dashboard
3. Update Cloudflare DNS CNAME to point to Railway domain
4. Migrate `~/.server-memory/memory.json` to Railway volume
5. Update Claude Code CLI and Xcode configs to use HTTP transport
6. Decommission local Docker container and Cloudflare Tunnel
