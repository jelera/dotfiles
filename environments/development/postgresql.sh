# Database configuration
export PGUSER="$USER"
export PGDATABASE="$USER"
export PGHOST="localhost"
export PGPORT="5432"

export PG_USABLE_VERSION=16

# Add homebrew PostgreSQL or Postgres.app to PATH for macOS
if [ -d "/opt/homebrew/opt/postgresql@$PG_USABLE_VERSION/bin" ]; then
    export PATH="/opt/homebrew/opt/postgresql@$PG_USABLE_VERSION/bin:$PATH"
elif [ -d "/Applications/Postgres.app/Contents/Versions/$PG_USABLE_VERSION/bin" ]; then
    export PATH="/Applications/Postgres.app/Contents/Versions/$PG_USABLE_VERSION/bin:$PATH"
fi

# Add homebrew libpq to PATH for macOS
if [ -d "/opt/homebrew/opt/libpq/bin" ]; then
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi
