# Update Test Branch

This repository contains workflows that can be used to automate cherry-picking from a feature branch to a secondary branch running parallel to the base branch.

## Workflows

### CreateTestBranch.yaml
Workflow for creating or resetting the test branch. This workflow:
- Creates a new test branch from the base branch if it doesn't exist
- Archives and recreates the test branch if it already exists
- Ensures the bot label exists for automated PRs
- Notifies open PRs when the test branch is reset

#### Usage
Trigger manually via `workflow_dispatch` with optional inputs:
- **base_branch**: Base branch to create the test branch from (defaults to repository's default branch)
- **test_prefix**: Prefix for feature test branches (default: `test/`)
- **test_branch**: Name of the test branch (defaults to `[test_prefix]/[base_branch]`)
- **bot_label**: Name of the bot label for automated PRs (default: `Automated`)
- **token**: Token name to use for GitHub API calls (default: `GHTOKENWORKFLOW`)

### UpdateRepositoryVariables.yaml
Workflow for configuring repository variables used by UpdateTestBranch workflow. This workflow:
- Updates repository variables that control UpdateTestBranch behavior
- Requires a Personal Access Token (PAT) with `repo` scope stored as `GHTOKENWORKFLOW` secret
- Can be run manually when you need to change the default configuration

#### Usage
1. Create a Personal Access Token with `repo` scope
2. Add it as a repository secret named `GHTOKENWORKFLOW`
3. Trigger manually via `workflow_dispatch` with inputs:
   - **test_branch**: Name of the test branch (if not provided, uses `[test_prefix]/[base_branch]`)
   - **test_prefix**: Prefix for feature test branches (default: `test/`)
   - **bot_label**: Name of the bot label for automated PRs (default: `Automated`)
   - **token_name**: Token name to use for GitHub API calls (default: `GHTOKENWORKFLOW`)

**Note**: Repository variables are optional. If not set, UpdateTestBranch will use built-in defaults.

### UpdateTestBranch.yaml
The main wrapper workflow that handles PR comments (`!update-test`) and coordinates the cherry-picking process. This workflow:
- Extracts PR information and configuration from comments
- Calls the core UpdateTestBranchCore workflow with appropriate parameters
- Handles post-processing like PR comments and cleanup

#### Usage

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
