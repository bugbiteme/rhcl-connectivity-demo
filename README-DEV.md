# MCP Gateway — Dev Preview

This document covers the **Model Context Protocol (MCP) Gateway** resources added to this demo, based on the [Kuadrant MCP Gateway dev preview](https://docs.kuadrant.io/dev/mcp-gateway/docs/guides/getting-started/).

These resources complement the main demo and are intentionally kept separate while the MCP Gateway feature is in dev preview.

---

## Overview

The MCP Gateway pattern exposes one or more MCP servers behind a Kubernetes Gateway, with Kuadrant policies enforcing authentication, authorization, and rate limiting on MCP traffic.

```
MCP Client
    │
    ▼
prod-web Gateway  (Istio)
    │
    ▼
HTTPRoute  mcp.travels.sandbox126.opentlc.com
    │  ◄── AuthPolicy (API key + OPA tool-method rules)
    │  ◄── RateLimitPolicy (per user, per group)
    │
    ▼
mcp-server-everything  (Deployment in mcp-server namespace)
    │
    ▼
MCPServerRegistration  ──►  MCP Broker aggregates tools as  everything_*
```

---

## Prerequisites

In addition to the main demo prerequisites:

- **MCP Gateway controller** installed in the cluster (kagenti/mcp-gateway):
  ```bash
  # Install Gateway API CRDs if not already present
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

  # Install MCP Gateway controller
  kubectl apply -k 'https://github.com/kagenti/mcp-gateway/config/install?ref=main'
  ```
- **cert-manager** with a `letsencrypt-prod` ClusterIssuer (for `tls-policy-mcp.yaml`).

---

## Project Structure

| Path | Description |
|------|-------------|
| **`app-mcp/`** | MCP server application resources (namespace, deployment, service, HTTPRoute, MCPServerRegistration) |
| **`rhcl-mcp/`** | Kuadrant policies for MCP traffic (AuthPolicy, RateLimitPolicy, TLSPolicy, API key secrets) |

### `app-mcp/`

| File | Description |
|------|-------------|
| `namespace-mcp.yaml` | Namespace `mcp-server` |
| `deployment-mcp.yaml` | `mcp-server-everything` deployment (port 3000, streamable-http transport) |
| `service-mcp.yaml` | Service (port 80 → 3000) |
| `http-route-mcp.yaml` | HTTPRoute for `mcp.travels.sandbox126.opentlc.com` → mcp-server-everything |
| `mcpserver-registration.yaml` | `MCPServerRegistration` registers this server with the MCP broker; tools are prefixed `everything_` |

### `rhcl-mcp/`

| File | Description |
|------|-------------|
| `secret-mcp-apikeys.yaml` | API key secrets for `mcp-user` and `mcp-admin` groups |
| `auth-policy-mcp.yaml` | AuthPolicy: API key auth + OPA rules gating access by `x-mcp-method` header and group |
| `rlp-mcp.yaml` | RateLimitPolicy: 30 req/min for `mcp-user`, 120 req/min for `mcp-admin`, keyed by user ID |
| `tls-policy-mcp.yaml` | TLSPolicy: cert-manager / Let's Encrypt TLS for the MCP route (optional) |

---

## Configuration

The same domain placeholder applies. Replace `sandbox126.opentlc.com` with your actual root domain:

```bash
grep -rl 'sandbox126.opentlc.com' app-mcp/ rhcl-mcp/ | \
  xargs sed -i 's/sandbox126\.opentlc\.com/YOUR_DOMAIN/g'
```

---

## Deploy Order

1. **MCP app**
   ```bash
   kubectl apply -f app-mcp/namespace-mcp.yaml
   kubectl apply -f app-mcp/deployment-mcp.yaml
   kubectl apply -f app-mcp/service-mcp.yaml
   kubectl apply -f app-mcp/http-route-mcp.yaml
   kubectl apply -f app-mcp/mcpserver-registration.yaml
   ```

2. **MCP policies**
   ```bash
   kubectl apply -f rhcl-mcp/secret-mcp-apikeys.yaml
   kubectl apply -f rhcl-mcp/auth-policy-mcp.yaml
   kubectl apply -f rhcl-mcp/rlp-mcp.yaml
   kubectl apply -f rhcl-mcp/tls-policy-mcp.yaml  # optional: requires cert-manager
   ```

> Apply the main gateway and its universal policies first (see the main README deploy order) before applying these MCP resources.

---

## API Keys

Two identities are provided for testing:

| Key | Group(s) | Allowed MCP methods |
|-----|----------|---------------------|
| `iamamcpuser` | `mcp-user` | `initialize`, `notifications/initialized`, `tools/list`, `tools/call` |
| `iamamcpadmin` | `mcp-user`, `mcp-admin` | All of the above + `resources/list`, `resources/read`, `prompts/list`, `prompts/get` |

---

## Testing

### List available tools (mcp-user)
```bash
curl -s https://mcp.travels.sandbox126.opentlc.com/mcp \
  -H "Authorization: APIKEY iamamcpuser" \
  -H "x-mcp-method: tools/list" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

### Call a tool (mcp-user)
```bash
curl -s https://mcp.travels.sandbox126.opentlc.com/mcp \
  -H "Authorization: APIKEY iamamcpuser" \
  -H "x-mcp-method: tools/call" \
  -H "x-mcp-toolname: everything_echo" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"everything_echo","arguments":{"message":"hello"}}}'
```

### List resources (mcp-admin only)
```bash
curl -s https://mcp.travels.sandbox126.opentlc.com/mcp \
  -H "Authorization: APIKEY iamamcpadmin" \
  -H "x-mcp-method: resources/list" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"resources/list","params":{}}'
```

### Verify rate limiting headers
```bash
curl -v https://mcp.travels.sandbox126.opentlc.com/mcp \
  -H "Authorization: APIKEY iamamcpuser" \
  -H "x-mcp-method: tools/list" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  2>&1 | grep -i 'x-ratelimit\|ratelimit'
```

---

## Auth Policy Design Notes

### `x-mcp-method` header
The MCP broker injects the `x-mcp-method` header on all forwarded requests, identifying the MCP protocol operation (e.g. `tools/call`, `resources/list`). The AuthPolicy OPA rule uses this to enforce method-level access control — for example, restricting resource and prompt access to `mcp-admin` users only.

### `/.well-known` bypass
The `when` predicate on the AuthPolicy excludes `/.well-known/*` paths from authentication. The MCP broker serves OAuth resource metadata at `/.well-known/oauth-protected-resource`, which must remain publicly accessible for MCP clients to discover the auth requirements.

### MCPServerRegistration
The `MCPServerRegistration` CRD (from [kagenti/mcp-gateway](https://github.com/kagenti/mcp-gateway)) tells the MCP broker to discover the backend server via the referenced HTTPRoute. The `toolPrefix: everything_` namespaces all tools from this server, avoiding collisions when multiple MCP servers are registered behind the same broker.

---

## References

- [Kuadrant MCP Gateway — Getting Started](https://docs.kuadrant.io/dev/mcp-gateway/docs/guides/getting-started/)
- [kagenti/mcp-gateway (GitHub)](https://github.com/kagenti/mcp-gateway)
- [Kuadrant MCP POC (GitHub)](https://github.com/Kuadrant/kuadrant-mcp-poc)
- [Advanced auth for MCP Gateway — Red Hat Developer](https://developers.redhat.com/articles/2025/12/12/advanced-authentication-authorization-mcp-gateway)
- [Kuadrant Documentation](https://docs.kuadrant.io/)
