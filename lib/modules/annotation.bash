#!/bin/bash

# Buildkite annotation module for displaying incident information

set -euo pipefail

# Create a Buildkite annotation with incident details
# Args: $1 - incident info, $2 - severity
create_incident_annotation() {
  local incident_info="$1"
  local severity="${2:-error}"
  
  # Map PagerDuty severity to Buildkite annotation style
  local style="error"
  case "${severity}" in
    critical)
      style="error"
      ;;
    error)
      style="error"
      ;;
    warning)
      style="warning"
      ;;
    info)
      style="info"
      ;;
  esac
  
  # Gather context
  local pipeline="${BUILDKITE_PIPELINE_SLUG:-unknown}"
  local build_number="${BUILDKITE_BUILD_NUMBER:-0}"
  local job_label="${BUILDKITE_LABEL:-unknown}"
  
  # Build the annotation content
  local annotation
  annotation=$(cat <<EOF
### 🚨 PagerDuty Incident Created

**Pipeline:** ${pipeline}  
**Build:** #${build_number}  
**Job:** ${job_label}  
**Severity:** ${severity}

${incident_info}

---
*Created by incident-pagerduty-buildkite-plugin*
EOF
)
  
  log_debug "Creating Buildkite annotation"
  
  # Create the annotation using buildkite-agent
  if command -v buildkite-agent >/dev/null 2>&1; then
    echo "${annotation}" | buildkite-agent annotate --style "${style}" --context "pagerduty-incident"
    log_success "Buildkite annotation created"
  else
    log_warning "buildkite-agent command not found, skipping annotation"
    # Still output to console
    echo ""
    echo "--- :pagerduty: PagerDuty Incident Created"
    echo "${annotation}"
  fi
}

# Create an error annotation if incident creation fails
create_error_annotation() {
  local error_message="$1"
  
  local annotation
  annotation=$(cat <<EOF
### ⚠️ Failed to Create PagerDuty Incident

**Error:** ${error_message}

Please check the plugin configuration and PagerDuty routing key.

---
*incident-pagerduty-buildkite-plugin*
EOF
)
  
  if command -v buildkite-agent >/dev/null 2>&1; then
    echo "${annotation}" | buildkite-agent annotate --style "warning" --context "pagerduty-error"
  else
    echo ""
    echo "--- :warning: PagerDuty Plugin Error"
    echo "${annotation}"
  fi
}
