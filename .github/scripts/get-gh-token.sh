#!/bin/bash
set -e

# This script accepts either a Personal Access Token (PAT) or a JWT string.
# If a PAT is provided, it outputs the PAT.
# If a JWT is provided, it uses the JWT to get a GitHub App installation token.
# Usage: get-gh-token.sh <pat_or_jwt>

INPUT="$1"

if [ -z "$INPUT" ]; then
    echo "::error::No token or JWT provided" >&2
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

# Check if input looks like a JWT (three dot-separated base64url parts)
if echo "$INPUT" | grep -Eq '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'; then
    echo "Detected JWT input, attempting to get installation token" >&2
    # Input is a JWT
    REPO_FULL_NAME="${GITHUB_REPOSITORY}"
    if [ -z "$REPO_FULL_NAME" ]; then
        echo "::error::GITHUB_REPOSITORY environment variable not set" >&2
        exit 1
    fi
    # Get installation ID
    echo "::debug::Getting installation ID for repository ${REPO_FULL_NAME}" >&2
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${INPUT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO_FULL_NAME}/installation")
    echo "::debug::Response retrieved" >&2

    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
    INSTALLATION_RESPONSE=$(echo "$HTTP_RESPONSE" | sed '$d')
    if [ "$HTTP_CODE" -ne 200 ]; then
        ERROR_MSG=$(echo "$INSTALLATION_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "::error::Failed to get installation ID (HTTP ${HTTP_CODE})" >&2
        echo "Error message: $ERROR_MSG" >&2
        exit 1
    fi
    INSTALLATION_ID=$(echo "$INSTALLATION_RESPONSE" | jq -r '.id // empty')
    if [ -z "$INSTALLATION_ID" ]; then
        echo "::error::Could not get installation ID for repository ${REPO_FULL_NAME}" >&2
        exit 1
    fi
    echo "::debug::Installation ID: ${INSTALLATION_ID}" >&2

    # Get installation access token
    echo "::debug::Requesting installation access token" >&2
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer ${INPUT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")
    echo "::debug::Response retrieved" >&2

    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
    TOKEN_RESPONSE=$(echo "$HTTP_RESPONSE" | sed '$d')
    if [ "$HTTP_CODE" -ne 201 ]; then
        ERROR_MSG=$(echo "$TOKEN_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "::error::Failed to generate installation token (HTTP ${HTTP_CODE})" >&2
        echo "Error message: $ERROR_MSG" >&2
        exit 1
    fi
    INSTALLATION_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
    if [ -z "$INSTALLATION_TOKEN" ]; then
        echo "::error::Could not generate installation token" >&2
        exit 1
    fi
    echo "Installation token obtained" >&2
    echo "$INSTALLATION_TOKEN"
else
    # Input is a PAT, just output it
    echo "Detected PAT input, outputting PAT" >&2
    echo "$INPUT"
fi
