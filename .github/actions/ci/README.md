# CI Validation GitHub Action

This composite action extracts the CI validation workflow logic into a reusable component. It reads validation plans, triggers workflows based on the plan configuration, monitors their execution, and generates comprehensive reports.

## Features

- **Multi-plan Support**: Supports multiple validation plans (single-plan, multivm-byos-plan, multivm-payg-plan)
- **Execution Modes**: Supports both serial and parallel execution of scenarios
- **Workflow Monitoring**: Tracks workflow execution status and waits for completion
- **Report Generation**: Creates detailed Markdown reports with execution summaries
- **Git Integration**: Automatically commits reports to a dedicated CI branch
- **Artifact Upload**: Uploads reports as GitHub Actions artifacts

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `ci_plan` | Path to the validation plan file. Options: `single-plan`, `multivm-byos-plan`, `multivm-payg-plan` | Yes | `single-plan` |
| `github_token` | GitHub token for API access | Yes | `${{ github.token }}` |

## Outputs

| Output | Description |
|--------|-------------|
| `results` | JSON string containing the results of all workflow executions |
| `report_timestamp` | Timestamp of the generated report |
| `report_url` | URL to the generated report on the CI branch |

## Usage

### Basic Usage

```yaml
jobs:
  execute-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Execute CI Validation
        uses: ./.github/actions/ci
        with:
          ci_plan: single-plan
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Usage with Custom Plan

```yaml
jobs:
  execute-validation:
    runs-on: ubuntu-latest
    outputs:
      results: ${{ steps.validation.outputs.results }}
      report_url: ${{ steps.validation.outputs.report_url }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Execute CI Validation
        id: validation
        uses: ./.github/actions/ci
        with:
          ci_plan: multivm-byos-plan
          github_token: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Process Results
        run: |
          echo "Validation completed. Report available at: ${{ steps.validation.outputs.report_url }}"
          echo "Results: ${{ steps.validation.outputs.results }}"
```

## Validation Plan Structure

The action expects validation plan files in `.github/ci/` with the following structure:

```json
{
  "validation_scenarios": [
    {
      "workflow": "validate-payg-singlenode.yaml",
      "run_mode": "parallel",
      "scenarios": [
        {
          "scenario": "Support database for PostgreSQL",
          "inputs": {
            "databaseType": "postgresql(flexible)",
            "jdkVersion": "eap8-openjdk17",
            "timeWaitBeforeDelete": "0"
          }
        }
      ]
    }
  ]
}
```

### Plan Configuration

- **workflow**: The workflow file to execute
- **run_mode**: Either `serial` (one after another) or `parallel` (all at once). Defaults to `parallel`
- **scenarios**: Array of scenarios to execute
  - **scenario**: Human-readable description of the scenario
  - **inputs**: Input parameters to pass to the workflow

## Report Generation

The action generates comprehensive reports that include:

- **Summary Statistics**: Total workflows, success/failure counts
- **Detailed Results**: Individual workflow results with duration and status
- **Execution URLs**: Direct links to workflow runs
- **Execution Notes**: Information about serial vs parallel execution

Reports are:

1. Uploaded as GitHub Actions artifacts
2. Committed to the `ci` branch in the `ci-report/` directory
3. Made available via GitHub Pages (if enabled)

## Error Handling

The action includes robust error handling:

- **Timeout Protection**: Workflows that don't complete within 60 minutes are marked as timed out
- **Retry Logic**: Multiple attempts to find and track workflow runs
- **Graceful Degradation**: Continues processing other scenarios if one fails
- **Detailed Logging**: Comprehensive console output for debugging

## Requirements

- GitHub repository with appropriate permissions
- Validation plan files in `.github/ci/` directory
- Target workflows that accept the inputs defined in the plan
- `jq` utility (available in GitHub-hosted runners)

## Migration from Original Workflow

If migrating from the original `ci-validation-workflows.yaml`, simply:

1. Ensure this action is in `.github/actions/ci/`
2. Update your workflow to use the action instead of the inline jobs
3. The same inputs and outputs are maintained for compatibility

## Troubleshooting

### Common Issues

1. **Plan file not found**: Ensure the validation plan file exists in `.github/ci/`
2. **Permission errors**: Verify the GitHub token has necessary permissions
3. **Workflow not found**: Check that target workflows exist and are spelled correctly
4. **Git errors**: Ensure the repository allows pushes to the `ci` branch

### Debug Information

The action provides extensive logging. Check the action logs for:

- Plan file reading and parsing
- Workflow dispatch responses
- Workflow run tracking
- Report generation steps
