#!/bin/bash

# Failure detection module for checking job and build status

set -euo pipefail

# Check if the current job has failed
# Returns 0 if job failed, 1 if job passed
check_job_failure() {
  local exit_status="${BUILDKITE_COMMAND_EXIT_STATUS:-0}"
  
  log_debug "Job exit status: ${exit_status}"
  
  if [[ "${exit_status}" != "0" ]]; then
    log_info "Job failure detected (exit status: ${exit_status})"
    return 0
  fi
  
  return 1
}

# Check if the build is failing
# Returns 0 if build is failing, 1 if build is passing
check_build_failure() {
  local build_url="${BUILDKITE_BUILD_URL:-}"
  # Try multiple token sources: BUILDKITE_AGENT_ACCESS_TOKEN (preferred) or BUILDKITE_API_TOKEN
  local build_api_access_token="${BUILDKITE_AGENT_ACCESS_TOKEN:-${BUILDKITE_API_TOKEN:-}}"
  
  if [[ -z "${build_url}" ]]; then
    log_warning "BUILDKITE_BUILD_URL not available, cannot check build status"
    return 1
  fi
  
  if [[ -z "${build_api_access_token}" ]]; then
    log_warning "No API token available (BUILDKITE_AGENT_ACCESS_TOKEN or BUILDKITE_API_TOKEN), cannot check build status"
    log_info "To enable build-level failure detection, ensure your agent has API access enabled"
    return 1
  fi
  
  log_debug "Checking build status via API: ${build_url}"
  
  # Query the Buildkite API for build status
  local build_json
  if ! build_json=$(curl -s -f -H "Authorization: Bearer ${build_api_access_token}" "${build_url}.json"); then
    log_warning "Failed to fetch build status from API"
    return 1
  fi
  
  # Extract build state using grep/sed (avoiding jq dependency)
  local build_state
  build_state=$(echo "${build_json}" | grep -o '"state":"[^"]*"' | head -1 | sed 's/"state":"\([^"]*\)"/\1/')
  
  log_debug "Build state: ${build_state}"
  
  # Check if build is in a failing state
  case "${build_state}" in
    failed|failing|canceled|canceling)
      log_info "Build failure detected (state: ${build_state})"
      return 0
      ;;
    *)
      log_debug "Build is not in a failed state (state: ${build_state})"
      return 1
      ;;
  esac
}

# Main failure detection logic based on check mode
# Args: $1 - check mode (job, build, or both)
# Returns 0 if failure detected, 1 if no failure
detect_failure() {
  local check_mode="${1:-job}"
  
  log_debug "Running failure detection with mode: ${check_mode}"
  
  case "${check_mode}" in
    job)
      check_job_failure
      return $?
      ;;
    build)
      check_build_failure
      return $?
      ;;
    both)
      if check_job_failure; then
        return 0
      fi
      if check_build_failure; then
        return 0
      fi
      return 1
      ;;
    *)
      log_error "Invalid check mode: ${check_mode}. Must be 'job', 'build', or 'both'"
      return 1
      ;;
  esac
}
