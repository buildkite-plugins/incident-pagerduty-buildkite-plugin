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
  local build_id="${BUILDKITE_BUILD_ID:-}"
  local org_slug="${BUILDKITE_ORGANIZATION_SLUG:-}"
  local pipeline_slug="${BUILDKITE_PIPELINE_SLUG:-}"
  
  local build_api_access_token="${BUILDKITE_API_TOKEN:-${BUILDKITE_AGENT_ACCESS_TOKEN:-}}"
  
  # Construct API URL - convert web URL to API URL or construct from build_id
  local api_url=""
  if [[ -n "${build_url}" && -n "${org_slug}" && -n "${pipeline_slug}" ]]; then
    # Extract build number from web URL: https://buildkite.com/{org}/{pipeline}/builds/{number}
    local build_number
    build_number=$(echo "${build_url}" | grep -o '/builds/[0-9]*' | grep -o '[0-9]*')
    
    if [[ -n "${build_number}" ]]; then
      # Convert to API URL format
      api_url="https://api.buildkite.com/v2/organizations/${org_slug}/pipelines/${pipeline_slug}/builds/${build_number}"
      log_debug "Converted web URL to API URL: ${api_url}"
    else
      log_warning "Could not extract build number from BUILD_URL: ${build_url}"
      return 1
    fi
  elif [[ -n "${build_id}" && -n "${org_slug}" && -n "${pipeline_slug}" ]]; then
    # Construct URL from build ID (UUID)
    api_url="https://api.buildkite.com/v2/organizations/${org_slug}/pipelines/${pipeline_slug}/builds/${build_id}"
    log_debug "Constructed API URL from build ID: ${api_url}"
  else
    log_warning "Cannot determine build API URL (need BUILDKITE_BUILD_URL or BUILDKITE_BUILD_ID)"
    return 1
  fi
  
  if [[ -z "${build_api_access_token}" ]]; then
    log_warning "Build-level failure detection requires BUILDKITE_API_TOKEN"
    log_info "The 'check: build' feature is optional and requires API access"
    log_info "To use this feature, add BUILDKITE_API_TOKEN to your pipeline secrets"
    log_info "Note: This gives API access to your organization - use with caution"
    log_info "Alternative: Use 'check: job' (default) which works without API access"
    return 1
  fi
  
  log_debug "Checking build status via API: ${api_url}"
  
  # Query the Buildkite API for build status
  local build_json
  local curl_exit_code
  # Query quietly but capture stderr for error context
  build_json=$(curl -s -S -f -H "Authorization: Bearer ${build_api_access_token}" "${api_url}" 2>&1)
  curl_exit_code=$?
  
  if [[ ${curl_exit_code} -ne 0 ]]; then
    log_warning "Failed to fetch build status from API (curl exit code: ${curl_exit_code})"
    log_info "API URL: ${api_url}"
    log_info "Error response: ${build_json}"
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
# Args: $1 - check mode (job or build)
# Returns 0 if failure detected, 1 if no failure
detect_failure() {
  local check_mode="${1:-job}"
  
  log_debug "Checking for failures (mode: ${check_mode})"
  
  case "${check_mode}" in
    job)
      check_job_failure
      ;;
    build)
      check_build_failure
      ;;
    *)
      log_error "Invalid check mode: ${check_mode}. Must be 'job' or 'build'"
      return 1
      ;;
  esac
}
