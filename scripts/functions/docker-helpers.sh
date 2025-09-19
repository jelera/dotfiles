#!/bin/bash
# Docker helper functions

# Clean up Docker resources
dcleanup() {
    echo "Cleaning up Docker containers and images..."
    docker container prune -f
    docker image prune -f
    docker volume prune -f
    docker network prune -f
    docker system df
}

# Stop all running containers
dstopall() {
    local containers=$(docker ps -q)
    if [ -n "$containers" ]; then
        docker stop $containers
        echo "Stopped all running containers"
    else
        echo "No running containers found"
    fi
}

# Remove all stopped containers
drmall() {
    local containers=$(docker ps -aq)
    if [ -n "$containers" ]; then
        docker rm $containers
        echo "Removed all stopped containers"
    else
        echo "No stopped containers found"
    fi
}

# Docker compose shortcuts for current directory
dcup() {
    docker compose up "$@"
}

dcdown() {
    docker compose down "$@"
}

dcupd() {
    docker compose up -d "$@"
}

dcbuild() {
    docker compose build "$@"
}

dclogs() {
    docker compose logs -f "$@"
}

# Execute command in running container
dexec() {
    if [ -z "$1" ]; then
        echo "Usage: dexec <container_name> [command]"
        return 1
    fi

    local container="$1"
    local command="${2:-/bin/bash}"
    docker exec -it "$container" "$command"
}
