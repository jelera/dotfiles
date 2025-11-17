#!/usr/bin/env bash
# Docker-related functions

# Remove stopped containers, unused images, and volumes
docker-clean() {
    docker container prune -f
    docker image prune -f
    docker volume prune -f
}

# Stop all running containers
docker-stop-all() {
    docker stop "$(docker ps -q)"
}

# Remove all containers
docker-remove-all() {
    docker rm "$(docker ps -a -q)"
}
