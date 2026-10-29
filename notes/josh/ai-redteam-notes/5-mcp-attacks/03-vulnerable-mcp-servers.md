# 03 — Vulnerable MCP Servers

**Jump to:** [Why This Matters](#why-this-matters) · [Sensitive Information Disclosure](#sensitive-information-disclosure) · [Broken Authorization](#broken-authorization) · [Injection Vulnerabilities](#injection-vulnerabilities) · [SSRF](#server-side-request-forgery-ssrf)

Scenario: you connect to/interact with someone else's MCP server directly — this is the scenario most like normal pentesting. The connecting LLM and its resilience are **irrelevant** here, because anyone with network access to the MCP server can call its capabilities directly, bypassing any need to jailbreak an LLM at all. Developers often wrongly assume MCP clients are "trusted" because they're LLM-mediated — they aren't.

## Why This Matters

MCP servers commonly hold API keys, access tokens, and credentials for the external systems they integrate with, and treat every tool/resource argument as coming from a trusted LLM. Treat all parameters as untrusted input, exactly like a normal API.

## Sensitive Information Disclosure

Lack of exception handling leaks internal details in error responses or logs. Enumerate resources first, then specifically probe anything log/error-adjacent:

```python
result = await client.read_resource("resource://logs")
```

Trigger errors deliberately on parameterized resources to surface stack traces/verbose errors — e.g. querying an invalid item against an external price API can leak the backing API key in the error message:
```
Error creating resource from template: ... Requests details: 'http://quantityapi.local/api/item/asd!' {... 'X-Api-Key': '7f1db571858da4cf0af43645812e1997'}
```

## Broken Authorization

IDOR-style issues if a resource is parameterized by an ID with no ownership check (e.g. `document://{doc_id}` pulling from cloud storage for any ID). Rarer than in typical web apps because the MCP server's *own* access token often already scopes what it can reach — but still worth testing on any per-user resource template.

## Injection Vulnerabilities

**SQL injection** via a resource template — probe with a single quote first:
```python
result = await client.read_resource("price://banana'--")
```
If slashes/spaces are rejected by URI parsing, URL-encode around it:
```python
await client.read_resource("price://x'%20UNION%20SELECT%201--")
```

**Command injection** via a tool that claims to whitelist commands — standard injection operators still work if validation is naive:
```python
await client.call_tool("execute_server_command", {"command": "date;id"})
```

## Server-Side Request Forgery (SSRF)

Any tool/resource that fetches a URL parameter without validating its destination:
```python
await client.call_tool("fetch_price_data", {"url": "http://127.0.0.1:22"})
```
Use response timing/error differences to port-scan the server's internal network (`Success` vs `Connection refused`).

## Mitigations to Flag

- Bind MCP servers to localhost or a restricted interface unless external access is explicitly required.
- Enforce TLS on any externally-reachable `Streamable HTTP` transport.
- Validate the `Origin` header to prevent DNS rebinding against localhost-bound servers.
- Treat every tool/resource parameter as untrusted input — same validation discipline as any other API.
- Run [mcp-scan](https://github.com/invariantlabs-ai/mcp-scan) against custom MCP server implementations.
