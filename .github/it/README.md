# Integration Test Validation Configuration

This directory contains JSON configuration files that define validation scenarios for the integration test workflow orchestrator. The validation system uses a reusable GitHub Action located at `.github/actions/it/action.yml` to execute these plans.

## Overview

The integration test validation system is a comprehensive testing framework designed to validate JBoss EAP deployments on Azure across multiple scenarios and configurations. It automates the execution of various deployment scenarios, monitors their progress, and generates detailed reports to ensure the reliability and quality of the Azure JBoss EAP templates.

### Key Features

- **Multi-Scenario Testing**: Execute multiple test scenarios simultaneously or sequentially
- **Flexible Execution Modes**: Support for both parallel and serial execution modes
- **Comprehensive Reporting**: Detailed reports with success/failure statistics and execution URLs
- **Automated Monitoring**: Real-time tracking of workflow execution with timeout protection
- **Resource Management**: Efficient cleanup and resource optimization for cost-effective testing

### Use Cases

- **Regression Testing**: Validate JBoss EAP templates after code changes or updates
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
- [Integration Test Action Usage](#integration-test-action-usage)
  - [Action Inputs](#action-inputs)
  - [Action Outputs](#action-outputs)
- [Structure Requirements](#structure-requirements)
- [Serial vs Parallel Execution](#serial-vs-parallel-execution)
- [Report Generation](#report-generation)
  - [Status Tracking](#status-tracking)
  - [Accessing Reports](#accessing-reports)
- [Error Handling](#error-handling)

## System Architecture

The integration test validation system consists of:

1. **Validation Plan Files** (this directory): JSON files defining what to test
2. **Integration Test Action** (`/.github/actions/it/action.yml`): Reusable composite action that executes the plans
3. **Integration Test Workflows** (`/.github/workflows/it-validation-*.yaml`): Workflows that trigger the action with specific plans
4. **Target Workflows** (`/.github/workflows/validate-*.yaml` and `build-artifact.yaml`): The actual validation workflows that get executed

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
          "scenario": "Support bringing your own VNET",
          "inputs": {
            "databaseType": "none",
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

1. **Integration Test Workflows**: The `it-validation-*.yaml` workflows are triggered (manually or scheduled)

2. **Plan File Mapping**: Each integration test workflow maps its input to a specific validation plan file in this directory

3. **Action Execution**: The workflow calls the integration test action (`/.github/actions/it/action.yml`) with the plan file path

4. **Plan Processing**: The action reads the validation plan and processes each scenario

5. **Execution Mode**: The optional `run_mode` property controls whether scenarios are executed serially or in parallel

6. **Workflow Triggering**: The action triggers the specified target workflows with the scenario inputs

7. **Monitoring**: The action monitors workflow execution and waits for completion

8. **Reporting**: Results are compiled into comprehensive reports and stored in the `ci` branch

## Available Files

- `validation-plan-single.json`: Single node JBoss EAP validation scenarios for both PAYG and BYOS deployments
- `validation-plan-multivm-payg.json`: Multi-VM JBoss EAP validation scenarios for PAYG deployments
- `validation-plan-multivm-byos.json`: Multi-VM JBoss EAP validation scenarios for BYOS deployments
- `validation-plan-build.json`: Build-only validation scenarios for template compilation and syntax checking

### File Content Overview

Each validation plan targets specific JBoss EAP deployment scenarios:

- **Single Node Plans**: Test JBoss EAP deployments on single Azure Virtual Machines with various database configurations and network setups
- **Multi-VM Plans**: Test JBoss EAP deployments across multiple Azure Virtual Machines in cluster configurations
- **Build Plans**: Validate artifact compilation and template syntax without actual deployments

## Getting Started

### Quick Start Guide

1. **Choose a Validation Plan**: Select the appropriate validation plan file based on your testing needs:
   - For single node deployments: `validation-plan-single.json`
   - For multi-VM PAYG deployments: `validation-plan-multivm-payg.json`
   - For multi-VM BYOS deployments: `validation-plan-multivm-byos.json`
   - For build validation only: `validation-plan-build.json`

2. **Trigger Integration Test Validation**: Use the GitHub Actions interface to manually trigger an integration test validation workflow:
   - Go to the "Actions" tab in the repository
   - Select the appropriate `it-validation-*` workflow:
     - `CI Validation Single VMs` - for single node deployments
     - `CI Validation Multi VM PAYG` - for multi-VM PAYG deployments
     - `CI Validation Multi VM BYOS` - for multi-VM BYOS deployments
     - `CI Validation Build` - for build-only validation
   - Click "Run workflow" and select your desired validation plan

3. **Monitor Progress**: Track the execution progress in the Actions tab and view real-time logs

4. **Review Results**: Check the generated reports in the `ci` branch under `ci-report/` directory

### Prerequisites

Before using the integration test validation system, ensure:

- [ ] Azure subscription with appropriate permissions
- [ ] GitHub repository with Actions enabled
- [ ] Required secrets configured in repository settings (RHSM credentials, Azure service principal, etc.)
- [ ] Access to the `ci` branch for report storage

## Integration Test Action Usage

The validation plans are consumed by the integration test action located at `/.github/actions/it/action.yml`. 

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

The integration test action generates comprehensive reports that include:

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
3. **Direct Links**: Use the `report_url` output from the integration test action
4. **API Access**: Programmatically access reports via GitHub API

#### Report File Naming Convention

Reports follow the naming pattern: `report-YYYYMMDD-HHMMSS.json`

Example: `report-20250804-103000.json` (August 4, 2025 at 10:30:00 UTC)

## Error Handling

The integration test action includes robust error handling:
- **Timeout Protection**: 60-minute maximum wait time per workflow
- **Failure Detection**: Integration test workflow fails if any triggered workflow fails, times out, or is cancelled
- **Resource Cleanup**: Automatic cleanup of Azure resources after test completion
- **Credential Management**: Secure handling of RHSM and Azure credentials
