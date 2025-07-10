#!/bin/bash

# Discord Webhook Runner Script
# Update the DISCORD_WEBHOOK URL below with your actual Discord webhook

export DISCORD_WEBHOOK=""
export DISCORD_USERNAME="AlertmanagerBot" 
export LISTEN_ADDRESS="127.0.0.1:9099"
export VERBOSE="ON"

echo "=== Alertmanager Discord Webhook ==="
echo "Listening on: $LISTEN_ADDRESS"
echo "Discord Username: $DISCORD_USERNAME"
echo "Verbose mode: $VERBOSE"
echo "===================================="

# Start the webhook service
./alertmanager-discord