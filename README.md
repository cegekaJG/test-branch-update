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
6. **The UpdateTestBranch workflow will be automatically triggered** for all test scenarios
7. Check the Actions tab and PR comments to see the test results

## Manual Usage of Core Workflow

The core `UpdateTestBranchCore` workflow can also be triggered manually:

1. Go to Actions → "Update Test Branch Core"
2. Click "Run workflow" 
3. Provide required inputs:
   - **test_branch**: Target test branch (e.g., `test/main`)
   - **feature_branch**: Source feature branch  
   - **base_branch**: Base branch for comparison
   - **feature_test_prefix**: Prefix for test branches (default: `test/`)
   - **bot_label**: PR label (default: `Automated`)
   - **use_github_token**: Use GITHUB_TOKEN vs GHTOKENWORKFLOW

This allows direct testing of the cherry-picking logic without PR comments.

### Example: Using Core Workflow from Another Workflow

```yaml
name: My Custom Workflow

on:
  workflow_dispatch:

jobs:
  update_test_branches:
    name: Update Multiple Test Branches
    uses: ./.github/workflows/UpdateTestBranchCore.yaml
    with:
      test_branch: "test/staging"
      feature_branch: "feature/my-feature" 
      base_branch: "main"
      feature_test_prefix: "test/"
      bot_label: "Automated"
      use_github_token: true
    secrets:
      GHTOKENWORKFLOW: ${{ secrets.GHTOKENWORKFLOW }}
```

### Example: Calling Core Workflow with Different Parameters

The core workflow supports various configurations:
- **Different test branches**: `test/main`, `test/staging`, `test/develop`
- **Custom prefixes**: `test/`, `staging/`, `qa/`
- **Multiple token types**: GitHub Token or custom workflow token
- **Custom labels**: `Automated`, `Test`, `Bot`, etc.

#### What Gets Tested

- ✅ Correct commit detection and cherry-picking
- ✅ Exclusion of already picked commits (merged and unmerged)
- ✅ Proper handling of cherry-pick failures
- ✅ Detection when no new commits need picking
- ✅ Automatic PR creation and management
- ✅ Proper error messaging and user guidance

## Workflows

### UpdateTestBranch.yaml
The main wrapper workflow that handles PR comments (`!update-test`) and coordinates the cherry-picking process. This workflow:
- Extracts PR information and configuration from comments
- Calls the core UpdateTestBranchCore workflow with appropriate parameters
- Handles post-processing like PR comments and cleanup

### UpdateTestBranchCore.yaml
The core cherry-picking workflow that is independent of PR context. This workflow:
- **Can be called by other workflows** via `workflow_call`
- **Can be triggered manually** via `workflow_dispatch` 
- Takes all necessary parameters as inputs (no dependency on secrets/variables)
- Focuses solely on cherry-picking commits and creating test PRs
- **Reusable** and **testable** in isolation

### SetupTestScenario.yaml  
Comprehensive test scenario generator for validating UpdateTestBranch functionality.

### DocumentMergedCommits.yaml
**DISABLED**: This workflow is no longer needed as UpdateTestBranch no longer relies on PR comments for tracking cherry-picked commits.

## New Architecture Benefits

✅ **Modularity**: Core cherry-picking logic is separate from PR comment handling  
✅ **Reusability**: Core workflow can be called by other workflows or triggered manually  
✅ **Testability**: Core workflow can be tested independently with specific inputs  
✅ **Maintainability**: Cleaner separation of concerns  
✅ **Backward Compatibility**: Existing `!update-test` comments still work  
✅ **Security**: Fixed critical code injection vulnerabilities from original workflow  
✅ **Permissions**: Explicit GitHub token permissions with minimal required scope  
