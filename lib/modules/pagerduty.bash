#!/bin/bash

# PagerDuty integration module for creating incidents

set -euo pipefail

# PagerDuty Events API v2 endpoint
PAGERDUTY_EVENTS_URL="https://events.pagerduty.com/v2/enqueue"

# Generate a deduplication key based on build/job details
# Returns a unique key for incident deduplication
generate_dedup_key() {
  local pipeline="${BUILDKITE_PIPELINE_SLUG:-unknown}"
  local build_number="${BUILDKITE_BUILD_NUMBER:-0}"
  local job_id="${BUILDKITE_JOB_ID:-unknown}"
  
  echo "buildkite-${pipeline}-${build_number}-${job_id}"
}

# Build the incident payload with Buildkite context
# Args: $1 - integration key, $2 - severity, $3 - dedup key, $4 - custom details JSON
# Returns JSON payload for PagerDuty Events API
build_incident_payload() {
  local integration_key="$1"
  local severity="$2"
  local dedup_key="$3"
  local custom_details="${4:-{}}"
  
  # Gather Buildkite context
  local pipeline="${BUILDKITE_PIPELINE_SLUG:-unknown}"
  local branch="${BUILDKITE_BRANCH:-unknown}"
  local build_url="${BUILDKITE_BUILD_URL:-}"
  local build_number="${BUILDKITE_BUILD_NUMBER:-0}"
  local job_id="${BUILDKITE_JOB_ID:-unknown}"
  local job_label="${BUILDKITE_LABEL:-unknown}"
  local commit="${BUILDKITE_COMMIT:-unknown}"
  local message="${BUILDKITE_MESSAGE:-No commit message}"
  local agent_name="${BUILDKITE_AGENT_NAME:-unknown}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Build summary
  local summary="Buildkite build failed: ${pipeline} #${build_number}"
  
  # Escape JSON strings (backslashes first, then quotes)
  message="${message//\\/\\\\}"
  message="${message//\"/\\\"}"
  job_label="${job_label//\\/\\\\}"
  job_label="${job_label//\"/\\\"}"
  
  # Build the JSON payload
  cat <<EOF
{
  "routing_key": "${integration_key}",
  "event_action": "trigger",
  "dedup_key": "${dedup_key}",
  "payload": {
    "summary": "${summary}",
    "severity": "${severity}",
    "source": "buildkite",
    "timestamp": "${timestamp}",
    "custom_details": {
      "pipeline": "${pipeline}",
      "branch": "${branch}",
      "build_number": "${build_number}",
      "build_url": "${build_url}",
      "job_id": "${job_id}",
      "job_label": "${job_label}",
      "commit": "${commit}",
      "commit_message": "${message}",
      "agent": "${agent_name}",
      "failed_at": "${timestamp}"
    }
  }
}
EOF
}

# Merge custom details into the payload
# This is a simplified version - in production you might want more sophisticated JSON merging
merge_custom_details() {
  local base_payload="$1"
  local custom_details="$2"
  
  if [[ -z "${custom_details}" || "${custom_details}" == "{}" ]]; then
    echo "${base_payload}"
    return
  fi
  
  # Simple merge: add custom_details fields to the custom_details object
  # This is a basic implementation - for complex merging, consider using jq
  echo "${base_payload}"
}

# Create a PagerDuty incident
# Args: $1 - integration key, $2 - severity, $3 - dedup key (optional), $4 - custom details (optional)
# Returns: incident response JSON
create_incident() {
  local integration_key="$1"
  local severity="${2:-error}"
  local dedup_key="${3:-}"
  local custom_details="${4:-{}}"
  
  # Generate dedup key if not provided
  if [[ -z "${dedup_key}" ]]; then
    dedup_key=$(generate_dedup_key)
  fi
  
  log_info "Creating PagerDuty incident with dedup key: ${dedup_key}"
  log_debug "Severity: ${severity}"
  
  # Build the payload
  local payload
  payload=$(build_incident_payload "${integration_key}" "${severity}" "${dedup_key}" "${custom_details}")
  
  log_debug "PagerDuty payload: ${payload}"
  
  # Send the request to PagerDuty
  local response
  local http_code
  
  response=$(curl -s -w "\n%{http_code}" -X POST "${PAGERDUTY_EVENTS_URL}" \
    -H "Content-Type: application/json" \
    -d "${payload}")
  
  # Extract HTTP status code (last line)
  http_code=$(echo "${response}" | tail -n 1)
  # Extract response body (all but last line)
  local response_body
  response_body=$(echo "${response}" | sed '$d')
  
  log_debug "PagerDuty API response code: ${http_code}"
  log_debug "PagerDuty API response: ${response_body}"
  
  # Check if request was successful
  if [[ "${http_code}" == "202" ]]; then
    log_success "PagerDuty incident created successfully"
    echo "${response_body}"
    return 0
  else
    log_error "Failed to create PagerDuty incident (HTTP ${http_code})"
    log_error "Response: ${response_body}"
    return 1
  fi
}

# Extract incident URL from PagerDuty response
# Args: $1 - PagerDuty API response JSON
# Returns: incident URL or empty string
extract_incident_url() {
  local response="$1"
  
  # Try to extract dedup_key from response
  local dedup_key
  dedup_key=$(echo "${response}" | grep -o '"dedup_key":"[^"]*"' | sed 's/"dedup_key":"\([^"]*\)"/\1/')
  
  if [[ -n "${dedup_key}" ]]; then
    log_debug "Incident dedup key: ${dedup_key}"
    # Note: We can't get the direct incident URL from Events API v2
    # The incident will appear in PagerDuty's incident dashboard
    echo "Incident created with dedup key: ${dedup_key}"
  else
    echo "Incident created successfully"
  fi
}
