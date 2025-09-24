#!/bin/bash
# Script to enable debug panel in production on Fly.io
# WARNING: Only use this for debugging production issues. Disable when done!

echo "=== Selecto Debug Panel Production Enabler ==="
echo ""
echo "⚠️  WARNING: This will enable the debug panel in production!"
echo "Make sure to disable it when you're done debugging."
echo ""

# Generate a secure token
TOKEN=$(openssl rand -base64 32)

echo "Generated secure token: $TOKEN"
echo ""
echo "To enable debug panel on Fly.io, run these commands:"
echo ""
echo "  fly secrets set SELECTO_DEBUG_ENABLED=true"
echo "  fly secrets set SELECTO_DEBUG_TOKEN=\"$TOKEN\""
echo ""
echo "To access the debug panel, append this to your URL:"
echo "  ?debug_token=$TOKEN"
echo ""
echo "For example:"
echo "  https://testselecto.fly.dev/pagila?debug_token=$TOKEN"
echo ""
echo "To disable debug panel when done:"
echo "  fly secrets unset SELECTO_DEBUG_ENABLED SELECTO_DEBUG_TOKEN"
echo ""
echo "You can also store the token in your browser session for persistent access."