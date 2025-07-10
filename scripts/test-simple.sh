#!/bin/bash

# Test connection với message đơn giản
echo "Testing simple Discord message..."

curl -X POST http://localhost:9099 \
  -H "Content-Type: application/json" \
  -d '{
    "receiver": "discord_webhook",
    "status": "firing", 
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "SimpleTest",
          "severity": "warning"
        },
        "annotations": {
          "summary": "Simple test alert",
          "description": "Short description"
        },
        "startsAt": "2025-07-03T10:00:00Z",
        "endsAt": "0001-01-01T00:00:00Z",
        "generatorURL": "http://localhost:9090/graph",
        "fingerprint": "simple123"
      }
    ],
    "groupLabels": {
      "alertname": "SimpleTest"
    },
    "commonLabels": {
      "alertname": "SimpleTest",
      "severity": "warning"
    },
    "commonAnnotations": {
      "summary": "Simple test alert"
    },
    "externalURL": "http://localhost:9093",
    "version": "4",
    "groupKey": "simple-test"
  }'

echo -e "\n\nSimple test completed!"
