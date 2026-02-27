curl -H 'Host: llm.travels.sandbox126.opentlc.com' https://llm.travels.sandbox126.opentlc.com/v1/models -i && echo

curl -H 'Host: llm.travels.sandbox126.opentlc.com' \
     -H 'Authorization: APIKEY user1' \
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
         }' 


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
           "stream": true,
           "stream_options": {
             "include_usage": true
           }
         }'  && echo

curl -H 'Host: llm.travels.sandbox126.opentlc.com' \
     -H 'Authorization: APIKEY iamagolduser' \
     -H 'Content-Type: application/json' \
     -X POST https://llm.travels.sandbox126.opentlc.com/v1/chat/completions \
     -w '\nHTTP code: %{http_code}\n' \
     -d '{
           "model": "meta-llama/Llama-3.1-8B-Instruct",
           "messages": [
             { "role": "user", "content": "Explain cloud native architecture" }
           ],
           "max_tokens": 200,
           "stream": false,
           "usage": true
         }' 