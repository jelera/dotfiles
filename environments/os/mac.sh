if [ "$(uname)" != "Darwin" ]; then
    return
fi

# Mac specific environment variables
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY="YES"
