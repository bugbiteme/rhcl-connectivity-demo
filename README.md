# Red Hat Connectivity Link — Token Rate Limiting Demo

This repository contains a **Red Hat Connectivity Link (RHCL)** demo focused on gateway policies, a mock LLM server for testing, and application-specific policies for an LLM API and a travel agency portal.

## Overview

This demo shows how to use **Kuadrant** policies on top of the Kubernetes Gateway API to enforce authentication, request rate limiting, and **token-based rate limiting** for LLM APIs — a pattern relevant to cost control and fair usage enforcement for AI workloads.

**Key components:**

- **Universal gateway policies** that apply to all traffic through the gateway (deny-by-default auth, low request rate limits).
- **Mock LLM server** deployment for testing token-based rate limiting.
- **LLM API policies** — authentication (API keys), authorization (free/gold groups), and **token rate limits** (TokenRateLimitPolicy) per user tier.
- **Travel agency portal policies** — HTTP routing, API key auth, and route-specific configuration.

The gateway used is Kubernetes Gateway API with Istio (`prod-web`), and policies are implemented with **Kuadrant** (AuthPolicy, RateLimitPolicy, TokenRateLimitPolicy).

---

## Getting Started

1. Review [Prerequisites](#prerequisites) and ensure your environment is ready.
2. Set your root domain — see [Configuration](#configuration).
3. Follow the [Deploy Order](#deploy-order) to apply manifests in sequence.
4. Use the [Scripts](#scripts) to test policies in action.

---

## Prerequisites

- **Provisioned demo environment.** This demo is intended for use with an existing Red Hat demo environment that has **Red Hat Connectivity operators installed and configured**. It has been tested with the **Red Hat Demo Platform** environment **"Application Connectivity Workshop (provided by App Developer BU)"**, available to Red Hat Associates and partners.
- OpenShift or Kubernetes with **Kubernetes Gateway API** and **Istio** (or compatible implementation). This demo has been **tested on OpenShift**.
- **Kuadrant** (and **Authorino**) for AuthPolicy, RateLimitPolicy, and TokenRateLimitPolicy.
- For token rate limiting: Kuadrant support for **TokenRateLimitPolicy** (Kuadrant CRDs and Limitador with token support).

---

## Configuration

All manifests and scripts use `.sandbox126.opentlc.com` as a placeholder domain. Replace it with your actual root domain before applying any resources:

```bash
# Preview affected files
grep -rl 'sandbox126.opentlc.com' .

# Replace across all manifests and scripts
grep -rl 'sandbox126.opentlc.com' . | xargs sed -i 's/sandbox126\.opentlc\.com/YOUR_DOMAIN/g'
```

Also verify the Gateway hostname in `gateways/prod-web.yaml` and all HTTPRoute hosts after substitution.

---

## Project Structure

| Path | Description |
|------|-------------|
| **`gateways/rhcl-gw/`** | Universal gateway-level policies (apply to all routes through the gateway) |
| **`app-llm/`** | Manifests to deploy the mock LLM server (namespace, deployment, service, HTTPRoute) |
| **`rhcl-llm/`** | Policies and config for the mock LLM API (auth, token rate limits, API key secrets) |
| **`rhcl-travel-agency/`** | Policies and routing for the travel agency portal application |

---

## Gateway Policies (`gateways/rhcl-gw/`)

Policies that target the **Gateway** (`prod-web`) and apply to all traffic through it:

- **`authpolicy-deny-all-gw.yaml`** — AuthPolicy that denies all requests by default (OPA `allow = false`). Route-specific AuthPolicies override this for allowed routes.
- **`rlp-gw-http.yaml`** — RateLimitPolicy with low limits (e.g. 5 requests per 10s) at the gateway level.

The Gateway definition itself is in **`gateways/prod-web.yaml`** (Istio, HTTPS, hostname `*.travels.sandbox126.opentlc.com`).

---

## Mock LLM Server (`app-llm/`)

Deploys a mock LLM service for testing token rate limiting and auth:

- **`namespace-llm.yaml`** — Namespace `llm-sim`.
- **`deployment-llm.yaml`** — Deployment for `trlp-tutorial-llm-sim` (image: `ghcr.io/llm-d/llm-d-inference-sim`), exposing port 8000.
- **`service-llm.yaml`** — Service `trlp-tutorial-llm-sim` (port 80 → 8000).
- **`http-route-llm.yaml`** — HTTPRoute for host `llm.travels.sandbox126.opentlc.com` → LLM service.

Apply these to get the LLM backend running before applying `rhcl-llm/` policies.

---

## LLM API Policies (`rhcl-llm/`)

Policies and configuration for the mock LLM API (auth + token rate limiting):

- **`auth-policy-llm.yaml`** — AuthPolicy for the LLM API:
  - API key auth with `Authorization: APIKEY <key>`.
  - Identity from secret annotations (`groups`, `user-id`).
  - OPA authorization allowing only `free` and `gold` groups.
  - Sample API key Secrets (free user, gold user) in `kuadrant-system`.
- **`token-rate-limit-llm.yaml`** — TokenRateLimitPolicy:
  - **free**: 50 tokens/minute on `/v1/chat/completions` when identity has group `free`.
  - **gold**: 200 tokens/minute on `/v1/chat/completions` when identity has group `gold`.
  - Counters keyed by `auth.identity.userid`.
- **`rlp-llm.yaml`** — Optional RateLimitPolicy for the LLM route (request-level limits).
- **`secret-user-tiers.yaml`** — Additional API key/identity secrets if used.

Use **`cli.sh`** to test the LLM endpoint with different API keys (`user1`, `iamafreeuser`, `iamagolduser`) and streaming vs non-streaming. Use **`monitor-token.sh`** to check TokenRateLimitPolicy status and rate-limit headers/Prometheus.

---

## Travel Agency Portal (`rhcl-travel-agency/`)

Policies and routing for the travel agency application:

- **`http-route-travels.yaml`** — HTTPRoute for host `api.travels.sandbox126.opentlc.com` → `travels` service in `travel-agency` (port 8000).
- **`auth-policy-travels.yaml`** — AuthPolicy for the travel agency route:
  - API key auth via query parameter `APIKEY`.
  - Secret selector `app: partner` (e.g. `apikey-blue` with key `blue`).
- **`rlp-travels.yaml`** — RateLimitPolicy for the travel agency route (if present).

---

## Scripts

Helper scripts for **debugging and demoing policies in action**:

- **`cli.sh`** — Example `curl` calls to the LLM API: list models, chat completions with different API keys (free/gold), streaming and non-streaming.
- **`monitor-token.sh`** — Commands to inspect TokenRateLimitPolicy status, rate-limit headers, and Prometheus metrics for token usage.
- **`trl-test.sh`** — Additional token rate limit testing.
- **`echo-dos.sh`** — Sends repeated requests to verify that gateway-level rate limiting is enforced.

---

## Deploy Order

1. **Gateway and universal policies**
   Apply `gateways/prod-web.yaml` and `gateways/rhcl-gw/*.yaml` (and ensure Kuadrant/Authorino are installed).

2. **Mock LLM app**
   Apply `app-llm/namespace-llm.yaml`, then deployment, service, and `app-llm/http-route-llm.yaml`.

3. **LLM policies**
   Apply `rhcl-llm/*.yaml` (auth policy, token rate limit policy, secrets, and any RLP).

4. **Travel agency**
   The travel agency app (`travels` service in the `travel-agency` namespace) is pre-installed in the Red Hat Demo Platform environment. Apply `rhcl-travel-agency/http-route-travels.yaml` and `rhcl-travel-agency/auth-policy-travels.yaml` (and RLP if used).

---

## TODO

- [ ] MCP Gateway Policies — add policies for Model Context Protocol traffic routing
- [ ] Config map for root domain — replace hardcoded domain references with a single configurable value

---

## References

- [Kuadrant Documentation](https://docs.kuadrant.io/) — AuthPolicy, RateLimitPolicy, TokenRateLimitPolicy.
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
