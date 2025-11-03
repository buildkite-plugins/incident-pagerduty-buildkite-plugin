# Library Structure

This directory contains shared utilities and modules for the Incident PagerDuty plugin.

## Core Files

- **`shared.bash`**: Common utilities and logging functions
- **`plugin.bash`**: Configuration reading helpers

## Modules

The plugin is organized into feature-specific modules:

### `modules/pagerduty.bash`

PagerDuty Events API v2 integration:

- `build_incident_payload()` - Constructs incident payload with Buildkite context
- `create_incident()` - Sends incident to PagerDuty
- `extract_incident_url()` - Parses incident URL from API response
- `generate_dedup_key()` - Creates deduplication keys

### `modules/failure_detector.bash`

Failure detection logic:

- `check_job_failure()` - Detects job-level failures via exit status
- `check_build_failure()` - Detects build-level failures via Buildkite API
- `detect_failure()` - Main entry point for failure detection

### `modules/annotation.bash`

Buildkite annotation creation:

- `create_incident_annotation()` - Creates annotations with incident links
- `create_error_annotation()` - Creates error annotations

## Structure

```bash
lib/
├── shared.bash                    # Common utilities and logging
├── plugin.bash                    # Configuration reading helpers
└── modules/                       # Feature modules
    ├── pagerduty.bash            # PagerDuty API integration
    ├── failure_detector.bash     # Failure detection logic
    └── annotation.bash           # Buildkite annotations
```

## Usage

Modules are loaded in the `pre-exit` hook:

```bash
# shellcheck source=lib/shared.bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/shared.bash"

# shellcheck source=lib/plugin.bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/plugin.bash"

# shellcheck source=lib/modules/pagerduty.bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/modules/pagerduty.bash"

# shellcheck source=lib/modules/failure_detector.bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/modules/failure_detector.bash"

# shellcheck source=lib/modules/annotation.bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/modules/annotation.bash"
```
