# Incident PagerDuty Buildkite Plugin

Automatically create PagerDuty incidents when Buildkite builds or jobs fail. This plugin runs as a `post-command` or `pre-exit` hook to detect failures and trigger incident creation via the [PagerDuty Events API v2](https://developer.pagerduty.com/docs/ZG9jOjExMDI5NTgw-events-api-v2-overview).

## Features

- 🚨 **Automatic incident creation** when builds or jobs fail
- 🎯 **Flexible failure detection** - check build status, job status, or both
- 📝 **Rich incident details** - includes pipeline, branch, build URL, job info, and timestamps
- 🔗 **Buildkite annotations** - creates annotations with direct links to PagerDuty incidents
- 🔑 **Secure credential handling** - uses environment variables for integration keys
- ⚙️ **Customizable severity levels** - critical, error, warning, or info

## Authentication

The plugin requires a PagerDuty integration key to create incidents via the `integration-key`. Use your preferred secret management tool to store the key.

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

The PagerDuty integration key for your service. This is a 32-character hex string (e.g., `95ed048753ef450ac065962fdgse1d1c`) that routes incidents to the correct service.

## Optional Configuration

### `check` (string)

What to check for failures. Options:

- `job` (default) - Create incident when the current job fails (requires a `command` in your step)
- `build` - Create incident when the build is failing (detects adjacent job failures while jobs are still running)
- `both` - Check both job and build status (requires a `command` in your step)

**Default:** `job`

**Note:** The `job` and `both` modes require a `command` in your pipeline step because they monitor the command's exit status.

### `severity` (string)

PagerDuty incident severity level. Options: `critical`, `error`, `warning`, `info`

**Default:** `error`

### `dedup-key` (string)

Custom deduplication key for the incident. If not provided, a key will be auto-generated based on the pipeline, build number, and job ID.

### `custom-details` (object)

Additional custom details to include in the PagerDuty incident payload. This can be any key-value pairs you want to attach to the incident.

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
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          check: build
```

### Check both build and job

Create incident if either the job or build fails:

```yaml
steps:
  - label: "🔍 Integration tests"
    command: "npm run test:integration"
    plugins:
      - aws-sm#v1.0.0:
          secrets:
            - name: PAGERDUTY_INTEGRATION_KEY
              key: pagerduty/integration-key
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          check: both
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
```

### With custom details

Include additional context in the incident:

```yaml
steps:
  - label: "📦 Build application"
    command: "make build"
    plugins:
      - secrets#v1.0.0:
          env:
            PAGERDUTY_INTEGRATION_KEY: pagerduty-integration-key
      - incident-pagerduty#v1.0.0:
          integration-key: "${PAGERDUTY_INTEGRATION_KEY}"
          custom-details:
            environment: production
            team: platform
            service: api-gateway
```

## How It Works

1. **Hook Execution**: The plugin runs as a `pre-exit` hook at the end of your job's lifecycle
2. **Failure Detection**: Checks the configured status (job, build, or both) for failures
3. **Incident Creation**: If a failure is detected, sends an event to PagerDuty's Events API v2
4. **Annotation**: Creates a Buildkite annotation with incident details and a direct link to the PagerDuty incident

### Important: Command Requirement

**The plugin requires a `command` in your pipeline step** when using `check: job` or `check: both` modes. This is because the plugin monitors the command's exit status to detect failures.

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
