#!/usr/bin/env bash
# Network-related functions

# Get external IP address
myip() {
    curl -s icanhazip.com
}

# Get local IP address
get_localip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - try en0 first
        ifconfig en0 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2}' | head -n1
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - try multiple methods
        if command -v ip &>/dev/null; then
            ip addr show | awk '/inet / && !/127.0.0.1/ {sub(/\/.*/, "", $2); print $2}' | head -n1
        elif command -v ifconfig &>/dev/null; then
            ifconfig | awk '/[Bb]*cast/ {sub(/addr:/, ""); print $2}' | head -n1
        elif command -v hostname &>/dev/null; then
            hostname -I 2>/dev/null | awk '{print $1}'
        fi
    fi
}

# Get local network info (all interfaces)
localnet() {
    if command -v ip &>/dev/null; then
        ip addr show | grep "inet " | grep -v 127.0.0.1
    else
        ifconfig | grep "inet " | grep -v 127.0.0.1
    fi
}

# Check if port is in use
port-check() {
    local port=$1
    if [[ -z "$port" ]]; then
        echo "Usage: port-check <port>"
        return 1
    fi

    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null ; then
        echo "Port $port is in use by:"
        lsof -Pi :"$port" -sTCP:LISTEN
    else
        echo "Port $port is available"
    fi
}

# Kill process on port
kill-port() {
    local port=$1
    if [[ -z "$port" ]]; then
        echo "Usage: kill-port <port>"
        return 1
    fi

    lsof -ti:"$port" | xargs kill -9
    echo "Killed process on port $port"
}

# Weather info
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?format=3"
}

# Detailed weather
weather-full() {
    local location="${1:-}"
    curl -s "wttr.in/${location}"
}
