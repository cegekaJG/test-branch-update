#!/bin/bash
set -e

# This script accepts either a Personal Access Token (PAT) or a JSON object with GitHub App credentials.
# If a PAT is provided, it returns nothing.
# If a JSON object is provided, it returns a JWT string.
# Usage: get-jwt.sh <token_or_credentials>

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

# Check if the input is a JSON object (GitHub App credentials)
if echo "$TOKEN_INPUT" | jq -e . >/dev/null 2>&1; then
    # Extract GitHub App credentials from JSON
    CLIENT_ID=$(echo "$TOKEN_INPUT" | jq -r '.GitHubAppClientId // empty')
    PRIVATE_KEY=$(echo "$TOKEN_INPUT" | jq -r '.PrivateKey // empty')

    if [ -z "$CLIENT_ID" ] || [ -z "$PRIVATE_KEY" ]; then
        echo "::error::Invalid GitHub App credentials. Missing GitHubAppClientId or PrivateKey" >&2
        exit 1
    fi

    # JWT header
    JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    # JWT payload
    NOW=$(date +%s)
    IAT=$((NOW - 60))
    EXP=$((NOW + 600))
    JWT_PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${CLIENT_ID}\"}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    JWT_UNSIGNED="${JWT_HEADER}.${JWT_PAYLOAD}"

    # Save private key to temporary file
    TEMP_KEY=$(mktemp)
    chmod 600 "$TEMP_KEY"
    if ! echo "$PRIVATE_KEY" | grep -q "BEGIN RSA PRIVATE KEY"; then
        echo "::error::PrivateKey is not in PEM format" >&2
        exit 1
    fi
    if echo "$PRIVATE_KEY" | grep -q '\\n'; then
        echo "$PRIVATE_KEY" | sed 's/\\n/\n/g' > "$TEMP_KEY"
    elif echo "$PRIVATE_KEY" | grep -q '^-----BEGIN RSA PRIVATE KEY-----[^-]*-----END RSA PRIVATE KEY-----$'; then
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
    echo "$JWT"

    rm -f "$TEMP_KEY"
else
    # Input is a PAT, return nothing
    exit 0
fi
