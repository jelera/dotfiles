#!/bin/bash
# Database helper functions

# PostgreSQL functions
pgstart() {
    local os=$(uname -s)
    if [ "$os" = "Darwin" ]; then
        brew services start postgresql@16
    else
        sudo systemctl start postgresql
    fi
    echo "PostgreSQL started"
}

pgstop() {
    local os=$(uname -s)
    if [ "$os" = "Darwin" ]; then
        brew services stop postgresql@16
    else
        sudo systemctl stop postgresql
    fi
    echo "PostgreSQL stopped"
}

pgrestart() {
    local os=$(uname -s)
    if [ "$os" = "Darwin" ]; then
        brew services restart postgresql@16
    else
        sudo systemctl restart postgresql
    fi
    echo "PostgreSQL restarted"
}

pgstatus() {
    local os=$(uname -s)
    if [ "$os" = "Darwin" ]; then
        brew services list | grep postgresql
    else
        systemctl status postgresql
    fi
}

# Create a new database
createdb_project() {
    if [ -z "$1" ]; then
        echo "Usage: createdb_project <database_name>"
        return 1
    fi

    createdb "$1"
    echo "Database '$1' created"
}

# Connect to a database
pgconnect() {
    local db_name="${1:-$USER}"
    psql -d "$db_name"
}
