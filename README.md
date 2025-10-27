# Incident PagerDuty Buildkite Plugin

Automatically create PagerDuty incidents when Buildkite builds or jobs fail.

## Features

- 🚨 **Automatic incident creation** when builds or jobs fail
- 🎯 **Flexible failure detection** - check build status or job status
- 📝 **Rich incident details** - includes pipeline, branch, build URL, job info, and timestamps
- 🔗 **Buildkite annotations** - creates annotations with direct links to PagerDuty incidents
- 🔑 **Secure credential handling** - uses environment variables for integration keys
- ⚙️ **Customizable severity levels** - critical, error, warning, or info

## Authentication

The plugin requires a PagerDuty integration key to create incidents via the `integration-key`. Use your preferred secret management tool to store the key.

> **Tip:** If you omit `integration-key` from the plugin configuration, the plugin will automatically read the value from the `INTEGRATION_KEY` environment variable (handy when a previous step exports it).

```yaml
steps:
  # Fetch secrets once for entire pipeline
  - label: "🔐 Fetch PagerDuty Credentials"
    key: "fetch-pagerduty-secrets"
    plugins:
      # Choose your secret management solution:
      - secrets#v1.0.0:                    # Buildkite Secrets
          env:
            PAGERDUTY_INTEGRATION_KEY: your-secret-key
      # OR
      - vault-secrets#v2.2.1:              # HashiCorp Vault
          server: ${VAULT_ADDR}
          secrets:
            - path: secret/pagerduty/integration-key
              field: PAGERDUTY_INTEGRATION_KEY
      # OR  
      - aws-sm#v1.0.0:                     # AWS Secrets Manager
          secrets:
            - name: PAGERDUTY_INTEGRATION_KEY
              key: pagerduty/integration-key
      # OR
      - aws-ssm#v1.0.0:                    # AWS SSM Parameter Store
          parameters:
            PAGERDUTY_INTEGRATION_KEY: /pagerduty/integration-key
```

## Required Configuration

### `integration-key` (string)

The PagerDuty integration key for your service. This is a 32-character hex string (e.g., `95ed048753ef450ac065962fdgse1d1c`) that routes incidents to the correct service. If omitted, the plugin falls back to the `INTEGRATION_KEY` environment variable when present.

## Optional Configuration

### `check` (string)

What to check for failures. Options:

- `job` (default) - Create incident when the current job fails (requires a `command` in your step)
- `build` - Create incident when the build is failing (detects adjacent job failures while jobs are still running)

**Default:** `job`

**Note:**

1. The `job` mode requires a `command` in your pipeline step because it monitors the command's exit status.
2. The `build` mode requires a `BUILDKITE_API_TOKEN` in your pipeline secrets because it monitors the build's status via the Buildkite API.

### `severity` (string)

PagerDuty incident severity level. Options: `critical`, `error`, `warning`, `info`

**Default:** `error`

### `dedup-key` (string)

Custom deduplication key for the incident. If not provided, a key will be auto-generated based on the pipeline, build number, and job ID.

## Examples

### Check job status

Minimal configuration:

```yaml
steps:
  - label: "🧪 Run tests"
    command: "npm test"
    plugins:
      - secrets#v1.0.0:
          env:
            PAGERDUTY_INTEGRATION_KEY: pagerduty-integration-key
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          check: job
```

### Check build status

Create incident when the build is failing (useful for detecting adjacent job failures):

```yaml
steps:
  - label: "🚀 Deploy"
    command: "./deploy.sh"
    plugins:
      - vault-secrets#v2.2.1:
          server: ${VAULT_ADDR}
          secrets:
            - path: secret/pagerduty/integration-key
              field: PAGERDUTY_INTEGRATION_KEY
            - path: secret/buildkite/api-token
              field: BUILDKITE_API_TOKEN
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          check: build
```

### Custom severity

Set incident severity to critical for production deployments:

```yaml
steps:
  - label: "🚨 Production deployment"
    command: "./deploy-prod.sh"
    plugins:
      - aws-ssm#v1.0.0:
          parameters:
            PAGERDUTY_INTEGRATION_KEY: /pagerduty/integration-key
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          severity: critical
          # check: job  # default
```

## How It Works

1. **Hook Execution**: The plugin runs as a `pre-exit` hook at the end of your job's lifecycle
2. **Failure Detection**: Checks the configured status (job or build) for failures
3. **Incident Creation**: If a failure is detected, sends an event to PagerDuty's Events API v2
4. **Annotation**: Creates a Buildkite annotation with incident details and a direct link to the PagerDuty incident

### Important: Command Requirement

**The plugin requires a `command` in your pipeline step** when using `check: job` mode. This is because the plugin monitors the command's exit status to detect failures.

**Note:** If using `check: build` mode only, a command is technically optional since the plugin only checks build-level status via the API. However, this is an uncommon use case.

## Requirements

- Bash
- `curl` (for API calls)
- PagerDuty integration key
- Buildkite agent with access to make HTTPS requests to `events.pagerduty.com`

## Compatibility

| Elastic Stack | Agent Stack K8s | Hosted (Mac) | Hosted (Linux) | Notes |
| :-----------: | :-------------: | :----------: | :------------: | :---- |
|       ✅       |        ✅        |      ✅       |       ✅        | Requires `curl` |

- ✅ Fully supported
- ⚠️ Partially supported
- ❌ Not supported

## 👩‍💻 Contributing

1. Follow the patterns established in the template
2. Add tests for new functionality
3. Update documentation for any new options
4. Ensure shellcheck passes (fix issues, don't just disable checks)
5. Test with the plugin tester

## Developing

**Run all tests:**

```bash
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```

**Validate plugin structure:**

```bash
docker run -it --rm -v "$PWD:/plugin:ro" buildkite/plugin-linter --id incident-pagerduty --path /plugin
```

**Run shellcheck:**

```bash
shellcheck hooks/* lib/*.bash
```

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
