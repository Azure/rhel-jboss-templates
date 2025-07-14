# CI Validation Configuration

This directory contains JSON configuration files that define validation scenarios for the CI workflow orchestrator. The validation system uses a reusable GitHub Action located at `.github/actions/ci/action.yml` to execute these plans.

## System Architecture

The CI validation system consists of:

1. **Validation Plan Files** (this directory): JSON files defining what to test
2. **CI Action** (`/.github/actions/ci/action.yml`): Reusable composite action that executes the plans
3. **CI Workflows** (`/.github/workflows/ci-validation-*.yaml`): Workflows that trigger the action with specific plans
4. **Target Workflows** (`/.github/workflows/validate-*.yaml`): The actual validation workflows that get executed

## Configuration Structure

The validation plan files use the following structure:

### Scenarios Structure
Each validation plan defines scenarios with descriptive names:

```json
{
  "validation_scenarios": [
    {
      "workflow": "validate-payg-singlenode.yaml",
      "run_mode": "serial",
      "scenarios": [
        {
          "scenario": "SQL Server with EAP 8 and OpenJDK 17",
          "inputs": {
            "databaseType": "mssqlserver",
            "jdkVersion": "eap8-openjdk17",
            "timeWaitBeforeDelete": "0"
          }
        }
      ]
    }
  ]
}
```

### Execution Modes

You can control how scenarios within a workflow are executed by using the optional `run_mode` property:

- **`"run_mode": "serial"`**: Scenarios are executed one after another. Each scenario must complete before the next one starts.
- **`"run_mode": "parallel"`** or **no `run_mode` specified**: Scenarios are executed simultaneously (default behavior).

**Example with serial execution:**
```json
{
  "validation_scenarios": [
    {
      "workflow": "validate-byos-multivm.yaml",
      "run_mode": "serial",
      "scenarios": [
        {
          "scenario": "First scenario",
          "inputs": { /* ... */ }
        },
        {
          "scenario": "Second scenario",
          "inputs": { /* ... */ }
        }
      ]
    }
  ]
}
```

**When to use serial mode:**
- Resource-intensive scenarios that might conflict if run simultaneously
- Scenarios that need to run in a specific order
- Debugging scenarios where you want to isolate issues
- Limited resource environments where parallel execution might cause failures

## How It Works

1. **CI Workflows**: The `ci-validation-*.yaml` workflows are triggered (manually or scheduled)

2. **Plan File Mapping**: Each CI workflow maps its input to a specific validation plan file in this directory

3. **Action Execution**: The workflow calls the CI action (`/.github/actions/ci/action.yml`) with the plan file path

4. **Plan Processing**: The action reads the validation plan and processes each scenario

5. **Execution Mode**: The optional `run_mode` property controls whether scenarios are executed serially or in parallel

6. **Workflow Triggering**: The action triggers the specified target workflows with the scenario inputs

7. **Monitoring**: The action monitors workflow execution and waits for completion

8. **Reporting**: Results are compiled into comprehensive reports and stored in the `ci` branch

## Benefits of the Scenarios Structure

- **Better Reporting**: Scenario names appear in the validation reports instead of raw parameter lists
- **Improved Logging**: Clearer identification of which scenario is being executed
- **Documentation**: Scenario names serve as inline documentation for what each scenario tests
- **Maintainability**: Easier to understand and maintain complex validation scenarios
- **Semantic Clarity**: "Scenarios" better describes what is being tested
- **Execution Control**: Serial execution mode allows for resource management and sequential testing

## Available Files

- `validation-plan-single.json`: Single VM validation scenarios
- `validation-plan-build.json`: Build-only validation scenarios  
- `validation-plan-multivm-payg.json`: Multi-VM PAYG validation plan with serial execution mode
- `validation-plan-multivm-byos.json`: Multi-VM BYOS validation plan

## CI Action Usage

The validation plans are consumed by the CI action located at `/.github/actions/ci/action.yml`. 

### Action Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `ci_file` | Path to the validation plan file | Yes |
| `github_token` | GitHub token for API access | Yes |

### Action Outputs

| Output | Description |
|--------|-------------|
| `results` | JSON string containing the results of all workflow executions |
| `report_timestamp` | Timestamp of the generated report |
| `report_url` | URL to the generated report on the CI branch |

### Example Usage in CI Workflows

```yaml
- name: Set validation plan file
  id: set-plan-file
  run: |
    case "${{ inputs.ci_plan }}" in
      single-plan)
        CI_FILE=".github/ci/validation-plan-single.json"
        ;;
      multivm-payg-plan)
        CI_FILE=".github/ci/validation-plan-multivm-payg.json"
        ;;
    esac
    echo "ci_file=$CI_FILE" >> $GITHUB_OUTPUT

- name: Execute CI Validation
  uses: ./.github/actions/ci
  with:
    ci_file: ${{ steps.set-plan-file.outputs.ci_file }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Structure Requirements

- Each plan must have a `validation_scenarios` array
- Each item in the array must have a `workflow` and `scenarios` field
- Each scenario must have a `scenario` name and an `inputs` object
- The optional `run_mode` field can be set to `"serial"` or `"parallel"` (default)
- Only the `inputs` object content is passed to the target workflow

## Serial vs Parallel Execution

### Parallel Execution (Default)
- All scenarios within a workflow are triggered simultaneously
- Faster overall execution time
- Suitable for independent scenarios that don't compete for resources

### Serial Execution
- Scenarios are executed one after another
- Each scenario must complete before the next one starts
- Longer overall execution time but better resource management
- Includes waiting and monitoring between scenarios
- Recommended for resource-intensive workloads or debugging

## Report Generation

The CI action generates comprehensive reports that include:

- **Summary Statistics**: Total workflows, success/failure counts including cancelled and timeout scenarios
- **Detailed Results**: Individual workflow results with duration and status  
- **Execution URLs**: Direct links to workflow runs
- **Execution Notes**: Information about serial vs parallel execution

Reports are:
1. Uploaded as GitHub Actions artifacts
2. Committed to the `ci` branch in the `ci-report/` directory
3. Accessible via the repository's CI branch

### Status Tracking

The system tracks all execution outcomes:
- **Success**: Workflows completed successfully
- **Failure**: Workflows failed during execution  
- **Timeout**: Workflows exceeded the 60-minute timeout limit
- **Cancelled**: Workflows manually cancelled by users
- **Other Failed**: Workflows with any other non-success status

## Error Handling

The CI action includes robust error handling:
- **Timeout Protection**: 60-minute maximum wait time per workflow
- **Retry Logic**: Multiple attempts to find and track workflow runs
- **Graceful Degradation**: Continues processing other scenarios if one fails
- **Comprehensive Logging**: Detailed console output for debugging
- **Failure Detection**: CI workflow fails if any triggered workflow fails, times out, or is cancelled

## Troubleshooting

### Common Issues
1. **Plan file not found**: Ensure the validation plan file exists at the specified path
2. **Permission errors**: Verify the GitHub token has necessary permissions
3. **Workflow not found**: Check that target workflows exist and are spelled correctly
4. **Git errors**: Ensure the repository allows pushes to the `ci` branch
5. **Invalid file path**: Verify the file path is correct and accessible from the repository root

### Debug Information
The CI action provides extensive logging. Check the action logs for:
- Plan file reading and parsing
- Workflow dispatch responses  
- Workflow run tracking
- Report generation steps
