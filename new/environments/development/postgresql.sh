# Database configuration
export PGUSER="$USER"
export PGDATABASE="$USER"
export PGHOST="localhost"
export PGPORT="5432"

# Add homebrew PostgreSQL to PATH for macOS
if [ -d "/opt/homebrew/opt/postgresql@16/bin" ]; then
    export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
fi
