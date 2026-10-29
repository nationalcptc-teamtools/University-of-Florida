# 01 — MCP Fundamentals

**Jump to:** [Architecture](#architecture) · [Capabilities](#capabilities) · [Protocol Flow](#protocol-flow) · [Enumerating a Server](#enumerating-a-server)

## Architecture

- **Host** — container/coordinator managing the LLM integration.
- **Client** — created by the host, connects to and communicates with an MCP server.
- **Server** — provides capabilities, locally or remotely.

## Capabilities

| Primitive | Controlled by | Description | Analogy |
|---|---|---|---|
| Prompts | User | Pre-defined templates the user selects | Slash commands |
| Resources | Application | Read-only context fetched by the client (URIs, optionally parameterized) | File contents |
| Tools | Model | State-changing actions the LLM can invoke | API POST requests |

Transport: `stdio` (same-machine only) or `Streamable HTTP` (server-sent events for push). Messages are JSON-RPC: `Request` (has `id`+`method`), `Response` (has `id`+`result`/`error`), `Notification` (no `id`, one-way).

## Protocol Flow

1. **Initialization** — client sends `initialize` (protocol version, capabilities, client info) → server responds with its own → client sends `notifications/initialized`.
2. **Operation** — `prompts/list`, `prompts/get`, `resources/list`, `resources/read`, `tools/list`, `tools/call`.
3. **Shutdown** — transport connection just closes; no explicit MCP-level message.

## Enumerating a Server

```python
import asyncio
from fastmcp import Client

client = Client("http://<target>:8000/mcp/")

async def main():
    async with client:
        print("Resources:", await client.list_resources())
        print("Resource Templates:", await client.list_resource_templates())
        print("Tools:", await client.list_tools())

asyncio.run(main())
```

Read every tool/resource **description** carefully before trusting the server — see [Malicious MCP Servers](./02-malicious-mcp-servers.md). For calling tools/resources directly during testing:

```python
result = await client.call_tool("<tool_name>", {"<param>": "<value>"})
result = await client.read_resource("<scheme>://<param>")
```

Capture traffic with Wireshark if you need to see raw JSON-RPC messages during initialization/operation — useful for spotting auth headers, API keys in transit, or malformed responses.
