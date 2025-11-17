#!/usr/bin/env bash
# Security and encryption functions

# Encrypt file with GPG
encrypt() {
    if [[ -z "$1" ]]; then
        echo "Usage: encrypt <file>"
        return 1
    fi
    gpg -ac --no-options "$1"
}

# Decrypt file with GPG
decrypt() {
    if [[ -z "$1" ]]; then
        echo "Usage: decrypt <file>"
        return 1
    fi
    gpg --no-options "$1"
}
