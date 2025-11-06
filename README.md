# Update Test Branch

This repository contains workflows that can be used to automate cherry-picking from a feature branch to a secondary branch running parallel to the base branch.

## Workflows

### CreateTestBranch.yaml

Workflow for creating or resetting the test branch. This workflow:

- Creates a new test branch from the base branch if it doesn't exist
- Archives and recreates the test branch if it already exists
- Ensures the bot label exists for automated PRs
- Notifies open PRs when the test branch is reset

The workflow reads configuration from repository variables (`UPDATETESTBRANCH_TEST_BRANCH`, `UPDATETESTBRANCH_FEATURE_TEST_PREFIX`, `UPDATETESTBRANCH_BOT_LABEL`) with fallbacks to default environment variables.

#### Usage

Trigger manually via `workflow_dispatch` with optional input:

- **base_branch**: Base branch to create the test branch from (defaults to repository's default branch)

**Configuration**: Set repository variables in Settings → Secrets and variables → Actions → Variables:

- `UPDATETESTBRANCH_TEST_BRANCH`: Name of the test branch (defaults to `test/[base_branch]`)
- `UPDATETESTBRANCH_FEATURE_TEST_PREFIX`: Prefix for feature test branches (default: `test/`)
- `UPDATETESTBRANCH_BOT_LABEL`: Label for automated PRs (default: `Automated`)

### UpdateTestBranch.yaml

The main wrapper workflow that handles PR comments (`!update-test`) and coordinates the cherry-picking process. This workflow:

- Extracts PR information and configuration from comments
- Calls the core UpdateTestBranchCore workflow with appropriate parameters
- Creates or updates pull requests for test branch changes
- Handles post-processing like reactions and comment cleanup

**Requirements**: This workflow requires a `UPDATETESTTOKEN` secret to automatically trigger pull request workflows. The secret can be either:

- A Personal Access Token (PAT) with `repo` scope
- GitHub App credentials in compressed JSON format: `{"GitHubAppClientId":"...","PrivateKey":"..."}`

The workflow will fail if this secret is not configured. For PAT setup instructions, see [GhTokenWorkflow documentation](https://github.com/microsoft/AL-Go/blob/main/Scenarios/GhTokenWorkflow.md). The setup is identical, with only the name of the secret being different.

#### Usage

Comment `!update-test` on any pull request to trigger the workflow.

### UpdateTestBranchCore.yaml

The core cherry-picking workflow that is independent of PR context. This workflow:

- **Can be called by other workflows** via `workflow_call`
- **Can be triggered manually** via `workflow_dispatch`
- Takes all necessary parameters as inputs (no dependency on secrets/variables)
- Focuses exclusively on git operations (cherry-picking commits, branching, pushing)

#### Usage

Example: Using Core Workflow from Another Workflow

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
```

### SetupTestScenario.yaml

**Testing Workflow**: Comprehensive testing workflow for UpdateTestBranchCore functionality. This workflow:

- **Uses only UpdateTestBranchCore** - directly calls the core workflow without external dependencies
- **No remote operations** - all test branches and commits are created without remote push
- **Self-contained execution** - eliminates external dependencies and runs independently
- **Self-contained testing** - each scenario validates UpdateTestBranchCore behavior independently
- Tests all major scenarios: basic cherry-pick, already-picked commits, conflicts, and no-new-commits

#### Usage

Can be triggered manually via `workflow_dispatch` to test UpdateTestBranchCore functionality:

```yaml
# Manual trigger example
# Navigate to Actions → Setup Test Scenario → Run workflow
# Select base branch (default: main) and test scenario (default: all)
```

### DocumentMergedCommits.yaml

**DISABLED**: This workflow is no longer needed as UpdateTestBranch no longer relies on PR comments for tracking cherry-picked commits.
