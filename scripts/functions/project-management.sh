#!/bin/bash
# Project management functions

# Create new project directory with template
newproject() {
    if [ -z "$1" ]; then
        echo "Usage: newproject <project-name> [template]"
        echo "Available templates: node, express, angular, react, go, rust, python, ruby, basic"
        return 1
    fi

    local project_name="$1"
    local template="${2:-basic}"
    local project_dir="$PROJECTS_DIR/$project_name"

    if [ -d "$project_dir" ]; then
        echo "Project directory already exists: $project_dir"
        return 1
    fi

    mkdir -p "$project_dir"
    cd "$project_dir"

    case "$template" in
        "node"|"nodejs")
            npm init -y
            mkdir -p src tests docs
            cat > src/__init__.py << 'PYEOF'
"""Main module for the project."""
PYEOF
            cat > requirements.txt << 'PYEOF'
# Add your dependencies here
PYEOF
            ;;
        "ruby")
            bundle init
            mkdir -p lib spec bin
            cat > lib/$project_name.rb << 'RBEOF'
# frozen_string_literal: true

module $(echo $project_name | sed 's/[^a-zA-Z0-9]//g' | sed 's/\b\w/\U&/g')
  VERSION = "0.1.0"
end
RBEOF
            echo -e ".bundle/\nvendor/\n*.gem\n*.rbc\n/.config\n/coverage/\n/InstalledFiles\n/pkg/\n/spec/reports/\n/spec/examples.txt\n/test/tmp/\n/test/version_tmp/\n/tmp/" > .gitignore
            ;;
        *)
            touch README.md
            echo "# $project_name" > README.md
            echo -e ".DS_Store\n*.log\n.env\ntmp/\ndist/" > .gitignore
            ;;
    esac

    git init
    git add .
    git commit -m "Initial commit"

    echo "Created project: $project_dir"
    echo "Template used: $template"
}

# Quick project navigation
proj() {
    if [ -z "$1" ]; then
        cd "$PROJECTS_DIR"
        return
    fi

    local project_path="$PROJECTS_DIR/$1"
    if [ -d "$project_path" ]; then
        cd "$project_path"
    else
        echo "Project not found: $1"
        echo "Available projects:"
        ls -1 "$PROJECTS_DIR"
    fi
}

# List all projects
projlist() {
    echo "Projects in $PROJECTS_DIR:"
    find "$PROJECTS_DIR" -maxdepth 2 -name ".git" -type d | sed 's|/.git||' | sed "s|$PROJECTS_DIR/||" | sort
}
