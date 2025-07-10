#!/bin/bash

# Discord Webhook Configuration
export DISCORD_WEBHOOK=""
export DISCORD_USERNAME="AlertBot"
export DISCORD_AVATAR_URL="https://avatars3.githubusercontent.com/u/3380462"
export LISTEN_ADDRESS="127.0.0.1:9094"
export VERBOSE="ON"

echo "Starting alertmanager-discord..."
echo "Listening on: $LISTEN_ADDRESS"
echo "Discord webhook: ${DISCORD_WEBHOOK:0:50}..."

# Start the application
./alertmanager-discord
