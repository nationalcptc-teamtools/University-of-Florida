# 5. MCP Attacks

MCP (Model Context Protocol, Anthropic, 2024) standardizes how LLM apps connect to external tools/data — think "USB for AI integrations." It's new (2024+) and under-scrutinized, so expect real bugs if a target uses it. Increasingly common to find in modern AI-enabled apps/agents.

## Sections
1. [MCP Fundamentals](./01-mcp-fundamentals.md) — architecture, capabilities, protocol flow, enumerating a target server.
2. [Malicious MCP Servers](./02-malicious-mcp-servers.md) — tool poisoning, rug pulls, tool shadowing (you control the server; victim's LLM app connects to it).
3. [Vulnerable MCP Servers](./03-vulnerable-mcp-servers.md) — direct injection/SQLi/SSRF against someone else's MCP server (you connect to it).
