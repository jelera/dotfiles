#!/usr/bin/env bash
# System information functions

# Display system information
sysinfo() {
    echo "System Information:"
    echo "==================="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS Version: $(sw_vers -productVersion)"
    elif [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        # shellcheck disable=SC2154
        echo "Distribution: $PRETTY_NAME"
    fi

    echo "Uptime: $(uptime)"
}
