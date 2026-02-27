curl -H 'Host: llm.travels.sandbox126.opentlc.com' \
     -H 'Authorization: APIKEY iamafreeuser' \
     -H 'Content-Type: application/json' \
     -X POST https://llm.travels.sandbox126.opentlc.com/v1/chat/completions \
     -w '\nHTTP code: %{http_code}\n' \
     -d '{
           "model": "meta-llama/Llama-3.1-8B-Instruct",
           "messages": [
             { "role": "user", "content": "What is Kubernetes?" }
           ],
           "max_tokens": 100,
           "stream": false,
           "usage": true
         }' && echo