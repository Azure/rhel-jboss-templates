# CI Validation Configuration

This directory contains JSON configuration files that define validation combinations for the CI workflow orchestrator.

## Configuration Structure

The validation plan files support two structures:

### New Structure (Recommended)
With named combinations that provide better reporting and clarity:

```json
{
  "validation_combinations": [
    {
      "workflow": "validate-payg-singlenode.yaml",
      "combinations": [
        {
          "name": "SQL Server with EAP 8 and OpenJDK 17",
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

### Legacy Structure (Still Supported)
Direct input structure without names:

```json
{
  "validation_combinations": [
    {
      "workflow": "validate-payg-singlenode.yaml",
      "combinations": [
        {
          "databaseType": "mssqlserver",
          "jdkVersion": "eap8-openjdk17",
          "timeWaitBeforeDelete": "0"
        }
      ]
    }
  ]
}
```

## How It Works

1. **Orchestrator Workflow**: The `ci-validation-orchestrator.yaml` workflow reads the plan file specified in the workflow dispatch input.

2. **Structure Detection**: The orchestrator automatically detects whether a combination uses the new structure (with `name` and `inputs`) or the legacy structure.

3. **Input Extraction**: For the new structure, only the content of the `inputs` object is passed to the target workflow. The `name` is used for logging and reporting purposes only.

4. **Backward Compatibility**: Existing validation plans using the legacy structure continue to work without modification.

## Benefits of the New Structure

- **Better Reporting**: Combination names appear in the validation reports instead of raw parameter lists
- **Improved Logging**: Clearer identification of which combination is being executed
- **Documentation**: Names serve as inline documentation for what each combination tests
- **Maintainability**: Easier to understand and maintain complex validation scenarios

## Available Files

- `validation-plan.json`: Complete validation plan (legacy structure)
- `validation-plan-build.json`: Build-only validation plan (updated to new structure)
- `validation-plan-with-names.json`: Example of the new structure with names
- `validation-plan-single.json`: Single validation example
- `validation-empty.json`: Empty template

## Usage

To use a validation plan, specify the file path when triggering the orchestrator workflow:

```yaml
with:
  plan_file: '.github/ci/validation-plan-with-names.json'
```
