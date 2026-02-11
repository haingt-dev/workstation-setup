# MCP Servers Setup Guide

Model Context Protocol (MCP) servers extend Claude's capabilities by providing access to external data sources and tools.

## Current Status

**System**: Fedora/Nobara Linux
**Container Runtime**: ✅ Podman installed
**Node.js/npm**: ❌ Not installed (required for most MCP servers)

## Quick Setup

### Install Node.js (Required for most MCP servers)

```bash
# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
sudo dnf install -y nodejs

# Verify installation
node --version
npm --version
npx --version
```

After installing Node.js, edit `~/.claude/mcp_settings.json` and set `"disabled": false` for the servers you want to enable.

## Available MCP Servers

### 1. Filesystem Server ⭐ HIGH VALUE
**Status**: Podman-based (can work without Node.js)
**Purpose**: Provides file system access to Projects, Obsidian vault, and Agent Global Hub
**Setup**:
```bash
# TODO: Need to build or find podman image for filesystem MCP
# Alternatively, wait for Node.js installation
```

### 2. Obsidian Server ⭐⭐⭐ HIGHEST VALUE
**Status**: Requires Node.js
**Purpose**: Semantic search and queries over your Obsidian vault
**Setup**:
```bash
# After installing Node.js:
# 1. Edit ~/.claude/mcp_settings.json
# 2. Change "disabled": true to "disabled": false for obsidian server
# 3. Restart Claude
```

**Why valuable**: Your Obsidian vault has rich knowledge (PARA structure, game design docs, etc.). Claude can query it directly!

### 3. Brave Search Server
**Status**: Requires Node.js + API key
**Purpose**: Web search capabilities
**Setup**:
```bash
# 1. Get API key: https://brave.com/search/api/
# 2. Edit ~/.claude/mcp_settings.json
# 3. Replace YOUR_BRAVE_API_KEY_HERE with actual key
# 4. Set "disabled": false
```

### 4. GitHub Server
**Status**: Requires Node.js + GitHub PAT
**Purpose**: Access GitHub repos, issues, PRs
**Setup**:
```bash
# 1. Create GitHub Personal Access Token:
#    https://github.com/settings/tokens
#    Scopes needed: repo, read:org, read:user
# 2. Edit ~/.claude/mcp_settings.json
# 3. Replace YOUR_GITHUB_TOKEN_HERE with token
# 4. Set "disabled": false
```

## Recommended Priority

Based on your workflow (high Obsidian usage, multiple code projects):

1. **Obsidian Server** (⭐⭐⭐) - Query your knowledge base from Claude
2. **Filesystem Server** (⭐⭐) - Access files across projects
3. **GitHub Server** (⭐) - If you use GitHub heavily
4. **Brave Search** (⭐) - For web research

## Testing MCP Servers

After enabling a server:

```bash
# Restart Claude
claude

# In Claude, test the server:
# "Can you search my Obsidian vault for notes about Wildtide?"
# "What files are in ~/Projects/Wildtide/src?"
```

## Troubleshooting

### Server not responding
1. Check logs: `~/.claude/debug/latest`
2. Verify command exists: `which npx` or `which podman`
3. Test command manually: `npx -y @modelcontextprotocol/server-obsidian /path/to/vault`

### Permission denied
- Ensure paths in mcp_settings.json are absolute and accessible
- Check file permissions on Obsidian vault

### API key errors
- Verify API key is correct and has not expired
- Check environment variables are set correctly

## Adding Custom MCP Servers

You can add custom MCP servers to `~/.claude/mcp_settings.json`:

```json
{
  "mcpServers": {
    "my-custom-server": {
      "command": "python",
      "args": ["/path/to/my_mcp_server.py"],
      "env": {
        "CUSTOM_VAR": "value"
      }
    }
  }
}
```

## Resources

- MCP Documentation: https://modelcontextprotocol.io
- Official MCP Servers: https://github.com/modelcontextprotocol/servers
- Claude MCP Guide: https://docs.anthropic.com/claude/docs/model-context-protocol

## Next Steps

1. **Install Node.js** (highest priority for MCP functionality)
2. **Enable Obsidian server** (massive value for your knowledge base)
3. **Get Brave API key** (if you need web search)
4. **Create GitHub PAT** (if you work with GitHub repos)

Run this to start:
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - && sudo dnf install -y nodejs
```

Then edit `~/.claude/mcp_settings.json` and enable the servers you want!
