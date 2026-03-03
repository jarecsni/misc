# misc

Personal tooling and scripts.

## xcode-behaviors

Scripts for Xcode Behaviors (`~/.xcode-behaviors/`).

### Setup

Copy scripts to their location:
```bash
cp xcode-behaviors/* ~/.xcode-behaviors/
chmod +x ~/.xcode-behaviors/*.sh
```

### inject-mcps.sh

Injects MCP servers into Xcode Claude Agent config. Run with `--help` for full usage.

Secrets are stored in macOS keychain — not in this repo. After cloning on a new machine, restore secrets with:
```bash
security add-generic-password -s "github-mcp-token" -a "$USER" -w "your-token"
```
