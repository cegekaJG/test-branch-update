#!/bin/bash
# Setup Test Scenario - UpdateTestBranchCore Testing
# This script replicates the logic of the SetupTestScenario.yaml GitHub Actions workflow

# Usage: ./SetupTestScenario.sh [base_branch] [run_number]
# If base_branch is not provided, defaults to 'master'

set -e

# Set default base branch
BASE_BRANCH="${1:-master}"
TEST_BRANCH_PREFIX="test/"
FEATURE_BRANCH_PREFIX="feature"

# Use run number or timestamp for scenario ID
SCENARIO_ID="${2:-$(date +%s)}"

TEST_BRANCH="${TEST_BRANCH_PREFIX}-${BASE_BRANCH}-${SCENARIO_ID}"
FEATURE_BRANCH="${FEATURE_BRANCH_PREFIX}-${SCENARIO_ID}"

# Output variables
echo "base_branch=${BASE_BRANCH}" >> "$GITHUB_OUTPUT"
echo "test_branch=${TEST_BRANCH}" >> "$GITHUB_OUTPUT"
echo "feature_branch=${FEATURE_BRANCH}" >> "$GITHUB_OUTPUT"

# Checkout repository and fetch base branch
# Assumes script is run in repo root

git fetch origin "$BASE_BRANCH"
git checkout "$BASE_BRANCH"
git checkout -b "$TEST_BRANCH"

# Add some base content to test branch
cat <<EOF > test/TEST_BRANCH_README.md
# Test Branch for Scenario $SCENARIO_ID
Based on base branch: $BASE_BRANCH
Created: $(date)
NOTE: This is a test branch
EOF

git add test/TEST_BRANCH_README.md
git commit -m "Initialize test branch $TEST_BRANCH"

echo "Prepared test branch: $TEST_BRANCH"

git checkout "$BASE_BRANCH"
git checkout -b "$FEATURE_BRANCH"

# Append lines to test/SampleFile.md
cat <<EOF >> test/SampleFile.md

# Sample File for Scenario $SCENARIO_ID
Base branch: $BASE_BRANCH
Created: $(date)
EOF

git add test/SampleFile.md
git commit -m "Update SampleFile"

cat <<EOF > test/FEATURE_BRANCH_README.md
# New feature for Scenario $SCENARIO_ID
Based on base branch: $BASE_BRANCH
Created: $(date)
EOF

git add test/FEATURE_BRANCH_README.md
git commit -m "Add FEATURE_BRANCH_README"

echo "Prepared feature branch: $FEATURE_BRANCH"