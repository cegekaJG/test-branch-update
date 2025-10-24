# Update Test Branch

This repository contains workflows that can be used to automate cherry-picking from a feature branch to a secondary branch running parallel to the base branch.

## Workflows

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
**Local Testing Workflow**: Comprehensive testing workflow for UpdateTestBranchCore functionality. This workflow:
- **Uses only UpdateTestBranchCore** - directly calls the core workflow instead of the PR-based wrapper
- **No remote operations** - all test branches and commits are created locally only
- **No PR creation** - eliminates dependency on pull requests and GitHub tokens
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
