#!/bin/bash

echo "Stopping BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose down

echo "Stopping AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose down

if [ -d ~/projects/development/anythingllm-sohn ]; then
    echo "Stopping AnythingLLM-Sohn..."
    cd ~/projects/development/anythingllm-sohn
    docker-compose down
fi

echo "All services stopped!"
