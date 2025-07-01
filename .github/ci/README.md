# CI Validation Configuration

This directory contains JSON configuration files that define validation scenarios for the CI workflow orchestrator.

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

1. **Orchestrator Workflow**: The `ci-validation-workflows.yaml` workflow reads the plan file specified in the workflow dispatch input.

2. **Scenario Processing**: Each scenario in the `scenarios` array contains a descriptive `scenario` name and an `inputs` object.

3. **Execution Mode**: The optional `run_mode` property controls whether scenarios are executed serially or in parallel.

4. **Input Extraction**: Only the content of the `inputs` object is passed to the target workflow. The `scenario` name is used for logging and reporting purposes only.

## Benefits of the Scenarios Structure

- **Better Reporting**: Scenario names appear in the validation reports instead of raw parameter lists
- **Improved Logging**: Clearer identification of which scenario is being executed
- **Documentation**: Scenario names serve as inline documentation for what each scenario tests
- **Maintainability**: Easier to understand and maintain complex validation scenarios
- **Semantic Clarity**: "Scenarios" better describes what is being tested
- **Execution Control**: Serial execution mode allows for resource management and sequential testing

## Available Files

- `validation-plan-single.json`: Single validation scenario example
- `validation-plan-multivm-payg.json`: Multi-VM PAYG validation plan with serial execution mode
- `validation-plan-multivm-byos.json`: Multi-VM BYOS validation plan with serial execution mode

## Usage

To use a validation plan, specify the file path when triggering the CI validation workflow:

```yaml
with:
  plan_file: '.github/ci/validation-plan-multivm-payg.json'
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
