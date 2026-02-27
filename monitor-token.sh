#!/usr/bin/env bash
# TokenRateLimitPolicy: trlp-tutorial-token-limits (ingress-gateway)

# 1) Policy status (Accepted/Programmed)
oc get tokenratelimitpolicy trlp-tutorial-token-limits -n ingress-gateway -o wide
oc get tokenratelimitpolicy trlp-tutorial-token-limits -n ingress-gateway -o jsonpath='{.status.conditions[?(@.type=="Accepted")].message}{"\n"}{.status.conditions[?(@.type=="Programmed")].message}{"\n"}'

# 2) How close a user is to the limit (per request):
#    Enable rate limit headers on Limitador so responses include remaining quota:
#      oc patch limitador limitador -n kuadrant-system --type=merge -p '{"spec":{"rateLimitHeaders":"DRAFT_VERSION_03"}}'
#    Then call your API and inspect response headers (e.g. X-RateLimit-Limit, X-RateLimit-Remaining).
#    Example (use your URL and API key):
#      curl -s -D - -o /dev/null -H 'Host: llm.travels.sandbox126.opentlc.com' \
#        -H 'Authorization: APIKEY iamafreeuser' -X POST https://llm.travels.sandbox126.opentlc.com/v1/chat/completions \
#        -H 'Content-Type: application/json' -d '{"model":"meta-llama/Llama-3.1-8B-Instruct","messages":[{"role":"user","content":"Hi"}],"max_tokens":10,"stream":false}' \
#        | grep -i ratelimit

# 3) Token counters (Prometheus, aggregate per limit name, not per user):
#    authorized_hits = tokens consumed; authorized_calls = allowed requests; limited_calls = rejected.
#    Query: curl -s "${PROMETHEUS_URL:-http://localhost:9090}/api/v1/query?query=authorized_hits" | jq '.data.result'
#    With exhaustive telemetry: limit_name label (e.g. free, gold). Patch: spec.telemetry: exhaustive

# 4) Kuadrant WASM config (gateway integration)
# oc get wasmplugin -n ingress-gateway kuadrant-prod-web -o yaml