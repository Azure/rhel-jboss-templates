#!/bin/bash

max_retries=${MAX_RETRIES:-20}
retry_interval=${RETRY_INTERVAL:-30}
attempt=1

while [ $attempt -le $max_retries ]; do
  response=$(curl -L -s -o /dev/null -w "%{http_code}" "${APP_ENDPOINT}/services/javadetails")
  echo "Response code: $response, Attempt: $attempt"

  if [ "$response" -eq 200 ]; then
    echo "appEndpoint is accessible"
    echo "status=success" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  echo "appEndpoint is not accessible. Retrying in $retry_interval seconds..."
  attempt=$((attempt + 1))
  sleep $retry_interval
done

echo "appEndpoint is not accessible after $max_retries attempts"
echo "status=failure" >> "$GITHUB_OUTPUT"
exit 1