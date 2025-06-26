# CI Validation Configuration

This directory contains JSON configuration files that define validation scenarios for the CI workflow orchestrator.

## Configuration Structure

The validation plan files use the following structure:

### Scenarios Structure
Each validation plan defines scenarios with descriptive names:

```json
{
  "validation_combinations": [
    {
      "workflow": "validate-payg-singlenode.yaml",
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

## How It Works

1. **Orchestrator Workflow**: The `ci-validation-orchestrator.yaml` workflow reads the plan file specified in the workflow dispatch input.

2. **Scenario Processing**: Each scenario in the `scenarios` array contains a descriptive `scenario` name and an `inputs` object.

3. **Input Extraction**: Only the content of the `inputs` object is passed to the target workflow. The `scenario` name is used for logging and reporting purposes only.

## Benefits of the Scenarios Structure

- **Better Reporting**: Scenario names appear in the validation reports instead of raw parameter lists
- **Improved Logging**: Clearer identification of which scenario is being executed
- **Documentation**: Scenario names serve as inline documentation for what each scenario tests
- **Maintainability**: Easier to understand and maintain complex validation scenarios
- **Semantic Clarity**: "Scenarios" better describes what is being tested

## Available Files

- `validation-plan.json`: Complete validation plan with multiple scenarios
- `validation-plan-build.json`: Build-only validation plan
- `validation-plan-single.json`: Single validation scenario example
- `validation-empty.json`: Empty template

## Usage

To use a validation plan, specify the file path when triggering the orchestrator workflow:

```yaml
with:
  plan_file: '.github/ci/validation-plan.json'
```

## Structure Requirements

- Each plan must have a `validation_combinations` array
- Each item in the array must have a `workflow` and `scenarios` field
- Each scenario must have a `scenario` name and an `inputs` object
- Only the `inputs` object content is passed to the target workflow
