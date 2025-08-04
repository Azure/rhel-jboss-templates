# CI Validation Configuration

This directory contains JSON configuration files that define validation scenarios for the CI workflow orchestrator. The validation system uses a reusable GitHub Action located at `.github/actions/ci/action.yml` to execute these plans.

## Overview

The CI validation system is a comprehensive integration testing framework designed to validate Azure JBoss EAP deployments across multiple scenarios and configurations. It automates the execution of various deployment scenarios, monitors their progress, and generates detailed reports to ensure the reliability and quality of the Azure JBoss templates.

### Key Features

- **Multi-Scenario Testing**: Execute multiple test scenarios simultaneously or sequentially
- **Flexible Execution Modes**: Support for both parallel and serial execution modes
- **Comprehensive Reporting**: Detailed reports with success/failure statistics and execution URLs
- **Automated Monitoring**: Real-time tracking of workflow execution with timeout protection
- **Resource Management**: Efficient cleanup and resource optimization for cost-effective testing

### Use Cases

- **Regression Testing**: Validate templates after code changes or updates
- **Release Validation**: Comprehensive testing before production releases
- **Configuration Testing**: Verify different deployment configurations and parameters
- **Performance Monitoring**: Track deployment times and resource utilization

## Table of Contents

- [System Architecture](#system-architecture)
- [Configuration Structure](#configuration-structure)
  - [Scenarios Structure](#scenarios-structure)
  - [Execution Modes](#execution-modes)
- [How It Works](#how-it-works)
- [Available Files](#available-files)
  - [File Content Overview](#file-content-overview)
- [Getting Started](#getting-started)
  - [Quick Start Guide](#quick-start-guide)
  - [Prerequisites](#prerequisites)
- [CI Action Usage](#ci-action-usage)
  - [Action Inputs](#action-inputs)
  - [Action Outputs](#action-outputs)
  - [Example Usage in CI Workflows](#example-usage-in-ci-workflows)
- [Structure Requirements](#structure-requirements)
- [Serial vs Parallel Execution](#serial-vs-parallel-execution)
- [Report Generation](#report-generation)
  - [Status Tracking](#status-tracking)
  - [Report Format](#report-format)
  - [Accessing Reports](#accessing-reports)
- [Error Handling](#error-handling)

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

## Available Files

- `validation-plan-single.json`: Single VM validation scenarios for both PAYG and BYOS deployments
- `validation-plan-build.json`: Build-only validation scenarios for template compilation and syntax checking
- `validation-plan-multivm-payg.json`: Multi-VM PAYG validation plan with serial execution mode
- `validation-plan-multivm-byos.json`: Multi-VM BYOS validation plan

## Getting Started

### Quick Start Guide

1. **Choose a Validation Plan**: Select the appropriate validation plan file based on your testing needs:
   - For single VM testing: `validation-plan-single.json`
   - For multi-VM testing: `validation-plan-multivm-payg.json` or `validation-plan-multivm-byos.json`
   - For build validation only: `validation-plan-build.json`

2. **Trigger CI Validation**: Use the GitHub Actions interface to manually trigger a CI validation workflow:
   - Go to the "Actions" tab in the repository
   - Select the appropriate `ci-validation-*` workflow
   - Click "Run workflow" and select your desired validation plan

3. **Monitor Progress**: Track the execution progress in the Actions tab and view real-time logs

4. **Review Results**: Check the generated reports in the `ci` branch under `ci-report/` directory

### Prerequisites

Before using the CI validation system, ensure:

- [ ] Azure subscription with appropriate permissions
- [ ] GitHub repository with Actions enabled
- [ ] Required secrets configured in repository settings
- [ ] Access to the `ci` branch for report storage

## CI Action Usage

The validation plans are consumed by the CI action located at `/.github/actions/ci/action.yml`. 

### Action Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `ci_file` | Path to the validation plan file | Yes |

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

### Accessing Reports

Reports can be accessed in multiple ways:

1. **GitHub Actions Artifacts**: Download reports directly from the workflow run artifacts
2. **CI Branch**: Browse reports in the `ci` branch under `ci-report/` directory  
3. **Direct Links**: Use the `report_url` output from the CI action
4. **API Access**: Programmatically access reports via GitHub API

#### Report File Naming Convention

Reports follow the naming pattern: `report-YYYYMMDD-HHMMSS.json`

Example: `report-20250804-103000.json` (August 4, 2025 at 10:30:00 UTC)

## Error Handling

The CI action includes robust error handling:
- **Timeout Protection**: 60-minute maximum wait time per workflow
- **Failure Detection**: CI workflow fails if any triggered workflow fails, times out, or is cancelled
