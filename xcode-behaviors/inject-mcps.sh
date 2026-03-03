#!/bin/bash

if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo ""
    echo "inject-mcps.sh — Inject MCP servers into Xcode Claude Agent config"
    echo ""
    echo "USAGE:"
    echo "  inject-mcps.sh <project-path>"
    echo ""
    echo "EXAMPLE:"
    echo "  inject-mcps.sh /Users/johnny/dev/TestApp"
    echo ""
    echo "HOW IT WORKS:"
    echo "  Reads MCP server definitions from:"
    echo "    ~/.xcode-behaviors/mcp-config.json"
    echo "  Injects them into:"
    echo "    ~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json"
    echo "  Creates the project entry if it doesn't exist yet."
    echo ""
    echo "STORING SECRETS IN KEYCHAIN:"
    echo "  Tokens are never stored in files. Use placeholders in mcp-config.json:"
    echo "    \"__KEYCHAIN:your-service-name__\""
    echo "  Store the token once with:"
    echo "    security add-generic-password -s \"your-service-name\" -a \"\$USER\" -w \"your-token\""
    echo "  Retrieve it manually with:"
    echo "    security find-generic-password -s \"your-service-name\" -w"
    echo ""
    echo "CURRENT MCP CONFIG:"
    echo "  ~/.xcode-behaviors/mcp-config.json"
    echo ""
    if [ -z "$1" ]; then
        echo "Error: project path required."
        exit 1
    fi
    exit 0
fi

export PROJECT_PATH="$1"
export CONFIG_PATH="$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json"
export MCP_PATH="$HOME/.xcode-behaviors/mcp-config.json"

python3 << 'PYEOF'
import json, os, re, subprocess

project_path = os.environ["PROJECT_PATH"]
config_path = os.environ["CONFIG_PATH"]
mcp_path = os.environ["MCP_PATH"]

with open(mcp_path) as f:
    mcp_str = f.read()

for match in re.finditer(r'__KEYCHAIN:([^_]+)__', mcp_str):
    placeholder = match.group(0)
    service = match.group(1)
    result = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True, text=True
    )
    mcp_str = mcp_str.replace(placeholder, result.stdout.strip())

mcps = json.loads(mcp_str)

with open(config_path) as f:
    config = json.load(f)

if project_path not in config["projects"]:
    print(f"Project '{project_path}' not found — creating entry...")
    config["projects"][project_path] = {
        "allowedTools": [],
        "mcpContextUris": [],
        "mcpServers": {},
        "enabledMcpjsonServers": [],
        "disabledMcpjsonServers": [],
        "hasTrustDialogAccepted": False,
        "projectOnboardingSeenCount": 0,
        "hasClaudeMdExternalIncludesApproved": False,
        "hasClaudeMdExternalIncludesWarningShown": False
    }

config["projects"][project_path]["mcpServers"].update(mcps)

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"MCPs injected into {project_path}")
PYEOF
