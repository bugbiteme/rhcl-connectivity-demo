while true; do
curl -k -w "%{http_code}" https://echo.travels.sandbox126.opentlc.com; echo;
done