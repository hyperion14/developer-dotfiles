#!/bin/bash

echo "=== Docker Containers ==="
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Disk Usage ==="
df -h /

echo ""
echo "=== Service Health ==="
curl -s http://localhost:3001 > /dev/null && echo "✓ AnythingLLM (3001): OK" || echo "✗ AnythingLLM (3001): DOWN"
curl -s http://localhost:3002 > /dev/null && echo "✓ AnythingLLM-Sohn (3002): OK" || echo "✗ AnythingLLM-Sohn (3002): DOWN"
curl -s http://localhost:5001/health > /dev/null && echo "✓ BHK Flask (5001): OK" || echo "✗ BHK Flask (5001): DOWN"
