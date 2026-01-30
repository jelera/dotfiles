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

# Start Colima with work laptop resource configuration
colima-start() {
    if ! command -v colima &>/dev/null; then
        echo "Error: colima not found. Install with: brew install colima"
        return 1
    fi

    # Check if already running
    if colima status 2>/dev/null | grep -q "colima is running"; then
        echo "Colima is already running"
        colima status
        return 0
    fi

    # Default work configuration: 8 CPUs, 24GB memory, 200GB disk
    local cpu="${COLIMA_CPU:-8}"
    local memory="${COLIMA_MEMORY:-24}"
    local disk="${COLIMA_DISK:-200}"

    echo "Starting Colima with: ${cpu} CPUs, ${memory}GB RAM, ${disk}GB disk"
    echo "Override with: COLIMA_CPU=4 COLIMA_MEMORY=16 COLIMA_DISK=100 colima-start"

    colima start --cpu "$cpu" --memory "$memory" --disk "$disk"
}
