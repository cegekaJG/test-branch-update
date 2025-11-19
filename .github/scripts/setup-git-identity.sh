#!/bin/bash
set -e

# This script configures Git identity using a JWT for GitHub App authentication.
# Usage: setup-git-identity.sh <jwt>

JWT="$1"

if [ -z "$JWT" ]; then
    echo "::error::No JWT provided. This script only accepts a JWT for GitHub App authentication." >&2
    exit 1
fi

# Check if required tools are available
if ! command -v jq &> /dev/null; then
    echo "::error::jq is required but not installed" >&2
    exit 1
fi
if ! command -v curl &> /dev/null; then
    echo "::error::curl is required but not installed" >&2
    exit 1
fi

# Get the authenticated app information using the JWT
echo "::debug::Retrieving GitHub App information using JWT" >&2
APP_INFO=$(curl -s -H "Authorization: Bearer ${JWT}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app")
echo "::debug::Response retrieved" >&2

# Validate that we got valid JSON response
if ! echo "$APP_INFO" | jq -e . >/dev/null 2>&1; then
    echo "::error::Failed to get valid response from GitHub API" >&2
    echo "Response: $APP_INFO" >&2
    exit 1
fi

APP_SLUG=$(echo "$APP_INFO" | jq -r '.slug // empty')
APP_NAME=$(echo "$APP_INFO" | jq -r '.name // empty')

if [ -z "$APP_SLUG" ]; then
    echo "::error::Could not retrieve GitHub App information from API response" >&2
    exit 1
fi

# Configure Git to use the GitHub App identity
# GitHub Apps use the format: app-slug[bot]
GIT_USER_NAME="${APP_NAME}"
GIT_USER_EMAIL="${APP_SLUG}[bot]@users.noreply.github.com"

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

echo "Git configured with GitHub App identity:" >&2
echo "  Name: $GIT_USER_NAME" >&2
echo "  Email: $GIT_USER_EMAIL" >&2
