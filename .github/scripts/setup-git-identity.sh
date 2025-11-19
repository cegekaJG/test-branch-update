#!/bin/bash
set -e

# This script configures Git identity based on the token type.
# If GitHub App credentials were used, it configures Git to use the app's identity.
# Otherwise, it uses the default GitHub Actions bot identity.
#
# Usage: setup-git-identity.sh <token_or_credentials>
#
# The input can be either:
# 1. No input - will use GitHub Actions bot identity
# 2. A Personal Access Token (string) - will use GitHub Actions bot identity
# 3. A JSON object with GitHub App credentials - will use GitHub App identity

TOKEN_INPUT="$1"

configure_github_actions_bot_identity() {
    echo "Detected Personal Access Token, using GitHub Actions bot identity" >&2

    # Use default GitHub Actions bot identity
    git config --global user.name "github-actions[bot]"
    git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

    echo "Git configured with GitHub Actions bot identity" >&2
}

if [ -z "$TOKEN_INPUT" ]; then
    configure_github_actions_bot_identity
    exit 0
fi

# Check if required tools are available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Check if the input is a JSON object (GitHub App credentials)
if echo "$TOKEN_INPUT" | jq -e . >/dev/null 2>&1; then
    echo "Detected GitHub App credentials, configuring Git to use app identity" >&2

    # Get the GitHub App slug (username)
    # We need to use the GH_TOKEN that should be set in the environment
    if [ -z "$GH_TOKEN" ]; then
        echo "Error: GH_TOKEN environment variable not set" >&2
        exit 1
    fi

    # Get the authenticated app information
    APP_INFO=$(curl -s -H "Authorization: token ${GH_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app")

    # Validate that we got valid JSON response
    if ! echo "$APP_INFO" | jq -e . >/dev/null 2>&1; then
        echo "Error: Failed to get valid response from GitHub API" >&2
        echo "Response: $APP_INFO" >&2
        exit 1
    fi

    APP_SLUG=$(echo "$APP_INFO" | jq -r '.slug // empty')
    APP_NAME=$(echo "$APP_INFO" | jq -r '.name // empty')

    if [ -z "$APP_SLUG" ]; then
        echo "Error: Could not retrieve GitHub App information from API response" >&2
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
else
    configure_github_actions_bot_identity
fi
