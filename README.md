# Red Hat Connectivity Link — Token Rate Limiting Demo

This repository contains a **Red Hat Connectivity Link (RHCL)** demo focused on gateway policies, a mock LLM server for testing, and application-specific policies for an LLM API and a travel agency portal.

## Overview

The demo shows:

- **Universal gateway policies** that apply to all traffic through the gateway (deny-by-default auth, low request rate limits).
- **Mock LLM server** deployment for testing token-based rate limiting.
- **LLM API policies** — authentication (API keys), authorization (free/gold groups), and **token rate limits** (TokenRateLimitPolicy) per user tier.
- **Travel agency portal policies** — HTTP routing, API key auth, and route-specific configuration.

The gateway used is Kubernetes Gateway API with Istio (`prod-web`), and policies are implemented with **Kuadrant** (AuthPolicy, RateLimitPolicy, TokenRateLimitPolicy).

---

## Project Structure

| Path | Description |
|------|-------------|
| **`gateways/rhcl-gw/`** | Universal gateway-level policies (apply to all routes through the gateway) |
| **`app-llm/`** | Manifests to deploy the mock LLM server (namespace, deployment, service, HTTPRoute) |
| **`rhcl-llm/`** | Policies and config for the mock LLM API (auth, token rate limits, API key secrets) |
| **`rhcl-travel-agency/`** | Policies and routing for the travel agency portal application |

---

## gateways/rhcl-gw/ — Universal Gateway Policies

Policies that target the **Gateway** (`prod-web`) and apply to all traffic through it:

- **`authpolicy-deny-all-gw.yaml`** — AuthPolicy that denies all requests by default (OPA `allow = false`). Route-specific AuthPolicies override this for allowed routes.
- **`rlp-gw-http.yaml`** — RateLimitPolicy with low limits (e.g. 5 requests per 10s) at the gateway level.

The Gateway definition itself is in **`gateways/prod-web.yaml`** (Istio, HTTPS, hostname `*.travels.sandbox126.opentlc.com`).

---

## app-llm/ — Mock LLM Server

Deploys a mock LLM service for testing token rate limiting and auth:

- **`namespace-llm.yaml`** — Namespace `llm-sim`.
- **`deployment-llm.yaml`** — Deployment for `trlp-tutorial-llm-sim` (image: `ghcr.io/llm-d/llm-d-inference-sim`), exposing port 8000.
- **`service-llm.yaml`** — Service `trlp-tutorial-llm-sim` (port 80 → 8000).
- **`http-route-llm.yaml`** — HTTPRoute for host `llm.travels.sandbox126.opentlc.com` → LLM service.

Apply these to get the LLM backend running before applying `rhcl-llm/` policies.

---

## rhcl-llm/ — LLM API Policies

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

## rhcl-travel-agency/ — Travel Agency Portal

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
- **`echo-dos.sh`** — Simple load/echo script (e.g. for basic stress or DoS-style testing).

---

## Deploy Order (suggested)

1. **Gateway and universal policies**  
   Apply `gateways/prod-web.yaml` and `gateways/rhcl-gw/*.yaml` (and ensure Kuadrant/Authorino are installed).

2. **Mock LLM app**  
   Apply `app-llm/namespace-llm.yaml`, then deployment, service, and `app-llm/http-route-llm.yaml`.

3. **LLM policies**  
   Apply `rhcl-llm/*.yaml` (auth policy, token rate limit policy, secrets, and any RLP).

4. **Travel agency**  
   Deploy the travel agency app and apply `rhcl-travel-agency/http-route-travels.yaml` and `rhcl-travel-agency/auth-policy-travels.yaml` (and RLP if used).

Adjust namespaces and hostnames to match your environment. Replace **`.sandbox126.opentlc.com`** with your root domain in DNS and in the manifests/scripts (e.g. Gateway hostnames, HTTPRoutes, and `cli.sh`).

---

## Prerequisites

- **Provisioned demo environment.** This demo is intended for use with an existing Red Hat demo environment that has **Red Hat Connectivity operators installed and configured**. It has been tested with the **Red Hat Demo Platform** environment **"Application Connectivity Workshop (provided by App Developer BU)"**, available to Red Hat Associates and partners.
- OpenShift or Kubernetes with **Kubernetes Gateway API** and **Istio** (or compatible implementation). This demo has been **tested on OpenShift**.
- **Kuadrant** (and **Authorino**) for AuthPolicy, RateLimitPolicy, and TokenRateLimitPolicy.
- For token rate limiting: Kuadrant support for **TokenRateLimitPolicy** (Kuadrant CRDs and Limitador with token support).

---

## References

- [Kuadrant](https://docs.kuadrant.io/) — AuthPolicy, RateLimitPolicy, TokenRateLimitPolicy.
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/).
- Red Hat Connectivity Link and service mesh documentation for your platform.
