#!/bin/bash

CONFIG_PATH="$HOME/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json"
MCP_PATH="$HOME/.xcode-behaviors/mcp-config.json"

if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo ""
    echo "inject-mcps.sh — Inject MCP servers into Xcode Claude Agent config"
    echo ""
    echo "USAGE:"
    echo "  inject-mcps.sh <project-path>   inject into a single project"
    echo "  inject-mcps.sh --all            inject into all projects"
    echo ""
    exit 0
fi

export PROJECT_ARG="$1"
export CONFIG_PATH
export MCP_PATH

python3 << 'PYEOF'
import json, os, re, subprocess

project_arg = os.environ["PROJECT_ARG"]
config_path = os.environ["CONFIG_PATH"]
mcp_path = os.environ["MCP_PATH"]

with open(mcp_path) as f:
    mcp_str = f.read()

# Resolve __KEYCHAIN:service-name__ placeholders
for match in re.finditer(r'__KEYCHAIN:([^_]+)__', mcp_str):
    placeholder = match.group(0)
    service = match.group(1)
    result = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"WARNING: Keychain entry '{service}' not found — placeholder left unresolved")
    else:
        mcp_str = mcp_str.replace(placeholder, result.stdout.strip())

mcps = json.loads(mcp_str)

with open(config_path) as f:
    config = json.load(f)

if project_arg == "--all":
    targets = list(config["projects"].keys())
    if not targets:
        print("No projects found in config.")
    for project_path in targets:
        config["projects"][project_path].setdefault("mcpServers", {}).update(mcps)
        print(f"MCPs injected into {project_path}")
else:
    project_path = project_arg
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
    config["projects"][project_path].setdefault("mcpServers", {}).update(mcps)
    print(f"MCPs injected into {project_path}")

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
