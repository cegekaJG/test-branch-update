# Update Test Branch

This repository contains comprehensive test scenarios for the "UpdateTestBranch.yaml" workflow.

## Test Scenarios

The repository includes a self-contained, repeatable test scenario workflow that validates all aspects of the UpdateTestBranch functionality:

### Setup Test Scenario Workflow

**File**: `.github/workflows/SetupTestScenario.yaml`

This workflow creates comprehensive test scenarios to validate the UpdateTestBranch workflow behavior. It can be triggered manually via GitHub Actions with configurable parameters.

#### Features

- **Self-contained**: Creates all necessary branches and PRs automatically
- **Repeatable**: Each run uses unique identifiers to avoid conflicts
- **Configurable**: Works with any base branch
- **Comprehensive reporting**: Detailed test results in workflow summary

#### Test Scenarios

1. **Basic Cherry-Pick**: Tests successful cherry-picking of multiple commits
2. **Already Picked Commits**: Tests detection and skipping of previously cherry-picked commits
3. **Cherry-Pick Conflicts**: Tests conflict handling and manual resolution workflow
4. **No New Commits**: Tests behavior when all commits are already picked

#### Usage

1. Go to the Actions tab in GitHub
2. Select "Setup Test Scenario - Comprehensive UpdateTestBranch Testing"
3. Click "Run workflow"
4. Configure options:
   - **Base branch**: The branch to test against (default: main)
   - **Test scenario**: Which scenarios to run (default: all)
5. Wait for setup to complete
6. Follow the generated test report to run individual tests
7. Comment `!update-test` on the created PRs to trigger UpdateTestBranch workflow

#### What Gets Tested

- ✅ Correct commit detection and cherry-picking
- ✅ Exclusion of already picked commits (merged and unmerged)
- ✅ Proper handling of cherry-pick failures
- ✅ Detection when no new commits need picking
- ✅ Automatic PR creation and management
- ✅ Proper error messaging and user guidance

## Workflows

### UpdateTestBranch.yaml
The main workflow that handles cherry-picking commits from feature PRs to test branches.

### SetupTestScenario.yaml  
Comprehensive test scenario generator for validating UpdateTestBranch functionality.

### DocumentMergedCommits.yaml
**DISABLED**: This workflow is no longer needed as UpdateTestBranch no longer relies on PR comments for tracking cherry-picked commits.
