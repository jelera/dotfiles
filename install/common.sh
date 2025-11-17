#!/usr/bin/env bash
# Common functions for dotfiles installation
# Source this file in other installation scripts

set -e  # Exit on error

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Log file path (can be overridden)
export LOG_FILE="${LOG_FILE:-}"
export LOG_DIR="${HOME}/.dotfiles-install-logs"

# Initialize log file on first warning/error
init_log_file() {
    # Only initialize once
    if [[ -n "$LOG_FILE" ]]; then
        return 0
    fi

    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi

    # Create timestamped log file
    LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d_%H%M%S).log"

    # Write header to log file
    {
        echo "========================================"
        echo "Dotfiles Installation Log"
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "OS: $(uname -s) $(uname -r)"
        echo "========================================"
        echo ""
    } > "$LOG_FILE"

    export LOG_FILE
}

# Write to log file (without color codes)
write_to_log() {
    # Initialize log file if needed
    if [[ -z "$LOG_FILE" ]]; then
        init_log_file
    fi

    # Strip ANSI color codes and write to log
    echo "[$(date '+%H:%M:%S')] $1" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    write_to_log "[WARNING] $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    write_to_log "[ERROR] $1"
}

log_step() {
    echo -e "\n${MAGENTA}==>${NC} $1"
}

log_dry_run() {
    echo -e "${CYAN}[DRY RUN]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if dry run mode is enabled
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Check if running with sudo/root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require non-root execution
require_non_root() {
    if is_root; then
        log_error "This script should not be run as root or with sudo"
        log_info "Run it as a regular user. It will ask for sudo when needed."
        exit 1
    fi
}

# Prompt user for confirmation
confirm() {
    local prompt="${1:-Are you sure?}"
    local default="${2:-n}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    while true; do
        read -rp "$prompt" response
        response=${response:-$default}

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Get absolute path of dotfiles directory
get_dotfiles_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    dirname "$script_dir"
}

# Create backup of existing file/directory
backup_if_exists() {
    local target="$1"
    local backup_dir
    backup_dir="${HOME}/.dotfiles.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -e "$target" ]]; then
        if [[ ! -d "$backup_dir" ]]; then
            mkdir -p "$backup_dir"
            log_info "Created backup directory: $backup_dir"
        fi

        local backup_path
        backup_path="${backup_dir}/$(basename "$target")"
        mv "$target" "$backup_path"
        log_warning "Backed up existing $(basename "$target") to $backup_path"
        return 0
    fi
    return 1
}

# Safe symlink creation with backup
create_symlink() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    if is_dry_run; then
        if [[ -e "$target" || -L "$target" ]]; then
            log_dry_run "Would backup and link: $(basename "$target") -> $source"
        else
            log_dry_run "Would link: $(basename "$target") -> $source"
        fi
        return 0
    fi

    # Backup existing file/dir/symlink
    if [[ -e "$target" || -L "$target" ]]; then
        backup_if_exists "$target"
    fi

    # Create parent directory if needed
    local target_dir
    target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi

    ln -sf "$source" "$target"
    log_success "Linked: $(basename "$target") -> $source"
}

# Download file with curl or wget
download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -qO "$output" "$url"
    else
        log_error "Neither curl nor wget found. Cannot download."
        return 1
    fi
}

# Check if script is being sourced or executed
is_sourced() {
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

# Get OS type (macos, ubuntu, etc)
get_os_type() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
            # shellcheck source=/dev/null
            . /etc/os-release
            # shellcheck disable=SC2154
            echo "${ID}"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# Get OS version
get_os_version() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sw_vers -productVersion
    elif [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        # shellcheck disable=SC2154
        echo "${VERSION_ID}"
    else
        echo "unknown"
    fi
}

# Check minimum OS version
check_os_version() {
    local required_version="$1"
    local current_version
    current_version="$(get_os_version)"

    if [[ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" == "$required_version" ]]; then
        return 0
    else
        return 1
    fi
}

# Print separator line
print_separator() {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# Print header with ASCII art
print_header() {
    local text="$1"
    echo ""
    print_separator
    echo -e "${CYAN}${text}${NC}"
    print_separator
    echo ""
}

# Retry command with exponential backoff
retry() {
    local max_attempts="${1}"
    local delay="${2}"
    local command=("${@:3}")
    local attempt=1

    while (( attempt <= max_attempts )); do
        if "${command[@]}"; then
            return 0
        fi

        if (( attempt < max_attempts )); then
            log_warning "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Add line to file if not present
add_line_to_file() {
    local line="$1"
    local file="$2"

    if [[ ! -f "$file" ]]; then
        echo "$line" > "$file"
        log_success "Created $file with content"
    elif ! grep -qF "$line" "$file"; then
        echo "$line" >> "$file"
        log_success "Added line to $file"
    else
        log_info "Line already present in $file"
    fi
}

# Source file if exists
safe_source() {
    local file="$1"
    if [[ -f "$file" ]]; then
        # shellcheck source=/dev/null
        source "$file"
        return 0
    fi
    return 1
}

# Export all functions if sourced
if is_sourced; then
    export -f command_exists
    export -f is_root
    export -f require_non_root
    export -f confirm
    export -f get_dotfiles_dir
    export -f backup_if_exists
    export -f create_symlink
    export -f download_file
    export -f get_os_type
    export -f get_os_version
    export -f check_os_version
    export -f print_separator
    export -f print_header
    export -f retry
    export -f add_line_to_file
    export -f safe_source
    export -f init_log_file
    export -f write_to_log
    export -f log_info
    export -f log_success
    export -f log_warning
    export -f log_error
    export -f log_step
    export -f log_dry_run
    export -f is_dry_run
fi
