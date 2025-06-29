#!/bin/bash

# Base directory that must already exist
WORK_DIR="/home/zonzo/workindir"
TEMPLATE_DIR="$(dirname "$(readlink -f "$0")")/template"

# Verify template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Error: Template directory not found at $TEMPLATE_DIR"
    echo "Please run generate_terraform_template.sh first to create the template"
    exit 1
fi

# Ask for Git repository URL
read -p "Enter Git repository URL to clone (leave empty to skip): " REPO_URL
rm -r REPO_URL 2>/dev/null # Remove any previous REPO_URL variable to avoid conflicts

# If cloning a repo
if [ -n "$REPO_URL" ]; then
    # Extract project name from repo URL
    REPO_NAME=$(basename -s .git "$REPO_URL")
    PROJECT_DIR="${WORK_DIR}/${REPO_NAME}"

    echo "Cloning repository into: $PROJECT_DIR"
    git clone "$REPO_URL" "$PROJECT_DIR"

    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone repository. Exiting."
        exit 1
    fi

    echo "✅ Repository cloned successfully."
else
    # Prompt user to enter a name for the project directory
    read -p "Enter project directory name (e.g. yourprojectname): " DIR_NAME
    PROJECT_DIR="${WORK_DIR}/${DIR_NAME}"

    echo "Creating new project directory at: $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
fi

# Copy template contents to project directory
echo "📁 Copying AWS Landing Zone template structure..."
echo "📌 From: $TEMPLATE_DIR"
echo "📌 To: $PROJECT_DIR"

# Use rsync for more reliable copying
if ! command -v rsync &> /dev/null; then
    echo "⚠️ rsync not found, using cp instead (some features may be limited)"
    cp -r "$TEMPLATE_DIR/." "$PROJECT_DIR/"
else
    rsync -a --ignore-existing "$TEMPLATE_DIR/" "$PROJECT_DIR/"
fi

# Set executable permissions for scripts
#chmod +x "$PROJECT_DIR"/scripts/*.sh

# Initialize Git if not cloned from repo
if [ -z "$REPO_URL" ] && [ ! -d "$PROJECT_DIR/.git" ]; then
    cd "$PROJECT_DIR" && git init
    echo "✅ Initialized new Git repository"
fi

echo "✅ Project structure created successfully at $PROJECT_DIR"