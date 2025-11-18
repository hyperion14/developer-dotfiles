#!/bin/bash

echo "Starting BHK RAG System..."
cd ~/projects/production/bhk-rag-system/docker
docker-compose up -d

echo "Starting AnythingLLM..."
cd ~/projects/production/anythingllm
docker-compose up -d

echo "Services started!"
docker ps
