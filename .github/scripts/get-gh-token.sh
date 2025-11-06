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
    echo "Error: No token or credentials provided" >&2
    exit 1
fi

# Check if the input is a JSON object (GitHub App credentials)
if echo "$TOKEN_INPUT" | jq -e . >/dev/null 2>&1; then
    # Extract GitHub App credentials from JSON
    CLIENT_ID=$(echo "$TOKEN_INPUT" | jq -r '.GitHubAppClientId // empty')
    PRIVATE_KEY=$(echo "$TOKEN_INPUT" | jq -r '.PrivateKey // empty')
    
    if [ -z "$CLIENT_ID" ] || [ -z "$PRIVATE_KEY" ]; then
        echo "Error: Invalid GitHub App credentials. Missing GitHubAppClientId or PrivateKey" >&2
        exit 1
    fi
    
    # Generate JWT for GitHub App authentication
    # JWT header
    JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # JWT payload
    NOW=$(date +%s)
    IAT=$((NOW - 60))  # Issued 60 seconds in the past to allow for clock drift
    EXP=$((NOW + 600)) # Expires in 10 minutes
    
    JWT_PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${CLIENT_ID}\"}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # Create signature
    JWT_UNSIGNED="${JWT_HEADER}.${JWT_PAYLOAD}"
    
    # Save private key to temporary file
    TEMP_KEY=$(mktemp)
    echo "$PRIVATE_KEY" > "$TEMP_KEY"
    
    # Sign the JWT
    JWT_SIGNATURE=$(echo -n "${JWT_UNSIGNED}" | openssl dgst -binary -sha256 -sign "$TEMP_KEY" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # Clean up temp file
    rm -f "$TEMP_KEY"
    
    # Complete JWT
    JWT="${JWT_UNSIGNED}.${JWT_SIGNATURE}"
    
    # Get the installation ID for this repository
    # First, we need to find the installation
    REPO_FULL_NAME="${GITHUB_REPOSITORY}"
    
    if [ -z "$REPO_FULL_NAME" ]; then
        echo "Error: GITHUB_REPOSITORY environment variable not set" >&2
        exit 1
    fi
    
    # Get installation ID
    INSTALLATION_RESPONSE=$(curl -s -H "Authorization: Bearer ${JWT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO_FULL_NAME}/installation")
    
    INSTALLATION_ID=$(echo "$INSTALLATION_RESPONSE" | jq -r '.id // empty')
    
    if [ -z "$INSTALLATION_ID" ]; then
        echo "Error: Could not get installation ID for repository ${REPO_FULL_NAME}" >&2
        echo "Response: $INSTALLATION_RESPONSE" >&2
        exit 1
    fi
    
    # Generate installation access token
    TOKEN_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer ${JWT}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")
    
    INSTALLATION_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
    
    if [ -z "$INSTALLATION_TOKEN" ]; then
        echo "Error: Could not generate installation token" >&2
        echo "Response: $TOKEN_RESPONSE" >&2
        exit 1
    fi
    
    # Output the installation token
    echo "$INSTALLATION_TOKEN"
else
    # Input is a regular PAT, just output it
    echo "$TOKEN_INPUT"
fi
