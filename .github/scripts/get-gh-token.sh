#!/bin/bash
set -e

# This script handles both Personal Access Tokens (PAT) and GitHub App credentials
# for authentication with GitHub CLI.
#
# Usage: get-gh-token.sh <token_or_credentials>
#
# The input can be either:
# 1. A Personal Access Token (string)
# 2. A JSON object with GitHub App credentials:
#    {"GitHubAppClientId":"...","PrivateKey":"..."}

TOKEN_INPUT="$1"

if [ -z "$TOKEN_INPUT" ]; then
    echo "::error::No token or credentials provided" >&2
    exit 1
fi

# Check if required tools are available
if ! command -v jq &> /dev/null; then
    echo "::error::jq is required but not installed" >&2
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "::error::openssl is required but not installed" >&2
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "::error::curl is required but not installed" >&2
    exit 1
fi

# Function to cleanup temporary files
cleanup_temp_files() {
    if [ -n "$TEMP_KEY" ] && [ -f "$TEMP_KEY" ]; then
        rm -f "$TEMP_KEY"
    fi
}

# Set trap to ensure cleanup on exit
trap cleanup_temp_files EXIT

# Check if the input is a JSON object (GitHub App credentials)
if echo "$TOKEN_INPUT" | jq -e . >/dev/null 2>&1; then
    echo "Detected GitHub App credentials" >&2

    # Extract GitHub App credentials from JSON
    CLIENT_ID=$(echo "$TOKEN_INPUT" | jq -r '.GitHubAppClientId // empty')
    PRIVATE_KEY=$(echo "$TOKEN_INPUT" | jq -r '.PrivateKey // empty')

    if [ -z "$CLIENT_ID" ] || [ -z "$PRIVATE_KEY" ]; then
        echo "::error::Invalid GitHub App credentials. Missing GitHubAppClientId or PrivateKey" >&2
        exit 1
    fi

    # Generate JWT for GitHub App authentication
    echo "::debug::Generating JWT for GitHub App authentication" >&2
    # JWT header
    JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # JWT payload
    NOW=$(date +%s)
    IAT=$((NOW - 60))  # Issued 60 seconds in the past to allow for clock drift
    EXP=$((NOW + 600)) # Expires in 10 minutes

    JWT_PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${CLIENT_ID}\"}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # Create signature
    JWT_UNSIGNED="${JWT_HEADER}.${JWT_PAYLOAD}"

    # Save private key to temporary file with secure permissions
    TEMP_KEY=$(mktemp)
    chmod 600 "$TEMP_KEY"
    # Ensure private key has proper PEM formatting
    if ! echo "$PRIVATE_KEY" | grep -q "BEGIN RSA PRIVATE KEY"; then
        echo "::error::PrivateKey is not in PEM format" >&2
        exit 1
    fi
    # Fix line breaks if needed
    # If the private key contains literal "\n", convert to real newlines
    if echo "$PRIVATE_KEY" | grep -q '\\n'; then
        echo "$PRIVATE_KEY" | sed 's/\\n/\n/g' > "$TEMP_KEY"
    elif echo "$PRIVATE_KEY" | grep -q '^-----BEGIN RSA PRIVATE KEY-----[^-]*-----END RSA PRIVATE KEY-----$'; then
        # Key is all on one line, reformat to PEM
        echo "$PRIVATE_KEY" | \
        sed -E 's/(-----BEGIN RSA PRIVATE KEY-----)(.*)(-----END RSA PRIVATE KEY-----)/\1\n\2\n\3/' | \
        awk '/-----BEGIN RSA PRIVATE KEY-----/ {print; next} /-----END RSA PRIVATE KEY-----/ {print; next} {for(i=1;i<=length;i+=64) print substr($0,i,64)}' > "$TEMP_KEY"
    else
        echo "$PRIVATE_KEY" > "$TEMP_KEY"
    fi

    # Sign the JWT
    JWT_SIGNATURE=$(echo -n "${JWT_UNSIGNED}" | openssl dgst -binary -sha256 -sign "$TEMP_KEY" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # Complete JWT
    JWT="${JWT_UNSIGNED}.${JWT_SIGNATURE}"
    echo "::debug::Generated JWT for GitHub App" >&2

    # Get the installation ID for this repository
    echo "::debug::Retrieving installation ID for the repository" >&2
    # First, we need to find the installation
    REPO_FULL_NAME="${GITHUB_REPOSITORY}"

    if [ -z "$REPO_FULL_NAME" ]; then
        echo "::error::GITHUB_REPOSITORY environment variable not set" >&2
        exit 1
    fi

    # Get installation ID with error handling
    echo "::debug::Sending request to ${REPO_FULL_NAME} installation endpoint" >&2
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${JWT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO_FULL_NAME}/installation")

    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
    INSTALLATION_RESPONSE=$(echo "$HTTP_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -ne 200 ]; then
        echo "::error::Failed to get installation ID (HTTP ${HTTP_CODE})" >&2
        echo "::debug:: Response: $HTTP_CODE" >&2
        # Only log error message, not full response to avoid exposing sensitive data
        ERROR_MSG=$(echo "$INSTALLATION_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "Error message: $ERROR_MSG" >&2
        exit 1
    fi

    INSTALLATION_ID=$(echo "$INSTALLATION_RESPONSE" | jq -r '.id // empty')

    if [ -z "$INSTALLATION_ID" ]; then
        echo "::error::Could not get installation ID for repository ${REPO_FULL_NAME}" >&2
        exit 1
    fi

    echo "::debug::Retrieved installation ID: ${INSTALLATION_ID}" >&2

    # Generate installation access token with error handling
    echo "::debug::Generating installation access token" >&2
    echo "::debug::Sending request to create access token for installation ID ${INSTALLATION_ID}" >&2
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer ${JWT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")

    HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
    TOKEN_RESPONSE=$(echo "$HTTP_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" -ne 201 ]; then
        # Only log error message, not full response to avoid exposing sensitive data
        ERROR_MSG=$(echo "$TOKEN_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        echo "::error::Failed to generate installation token (HTTP ${HTTP_CODE})\nError message:\n${ERROR_MSG}" >&2
        echo "::debug:: Response: $HTTP_CODE" >&2
        exit 1
    fi

    INSTALLATION_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')

    if [ -z "$INSTALLATION_TOKEN" ]; then
        echo "::error::Could not generate installation token" >&2
        exit 1
    fi

    # Output the installation token
    echo "$INSTALLATION_TOKEN"
else
    echo "Detected Personal Access Token (PAT) credentials (raw string)" >&2

    # Input is a regular PAT, just output it
    echo "$TOKEN_INPUT"
fi
