#!/bin/bash

# Quick start script for emacs-openclaw server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/server"

echo "🚀 Starting OpenClaw Google Tools Server..."
echo ""
echo "📋 Checking for client_secret.json..."

if [ ! -f client_secret.json ]; then
    echo "❌ client_secret.json not found!"
    echo ""
    echo "To set up OAuth:"
    echo "1. Go to https://console.cloud.google.com"
    echo "2. Create a new project (or select existing)"
    echo "3. Enable Gmail API and Google Calendar API"
    echo "4. Create OAuth 2.0 Client ID (Desktop app)"
    echo "5. Download credentials as client_secret.json"
    echo "6. Place it in: $SCRIPT_DIR/server/"
    echo ""
    exit 1
fi

echo "✅ client_secret.json found"
echo ""
echo "📦 Checking Python dependencies..."

if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "⚠️  Dependencies not installed. Running: pip install -r requirements.txt"
    pip install -r requirements.txt
fi

echo "✅ Dependencies OK"
echo ""
echo "🌐 Starting server on http://127.0.0.1:3333"
echo "📝 Logs will be written to logs.txt"
echo ""
echo "Press Ctrl+C to stop"
echo ""

python3 -m uvicorn server:app --host 127.0.0.1 --port 3333 --reload
