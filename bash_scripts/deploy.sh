#!/bin/bash

echo "===================================="
echo " DevOps Deployment Script"
echo "===================================="

echo "Stopping old container..."
docker stop devops-nginx 2>/dev/null
docker rm devops-nginx 2>/dev/null

echo "Building Docker image..."
docker build -t devops-nginx ./docker

echo "Starting new container..."
docker run -d \
  --name devops-nginx \
  -p 8080:80 \
  devops-nginx

echo "===================================="
echo "Deployment Completed Successfully!"
echo "Application: http://localhost:8080"
echo "===================================="