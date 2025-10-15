#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty

  # Set common variables for all tests
  export BUILDKITE="true"
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_INTEGRATION_KEY='95ed048753ef450ac065962fdaee1d1c'
  export BUILDKITE_PIPELINE_SLUG='test-pipeline'
  export BUILDKITE_BUILD_NUMBER='123'
  export BUILDKITE_BUILD_URL='https://buildkite.com/test-org/test-pipeline/builds/123'
  export BUILDKITE_JOB_ID='abc-123-def'
  export BUILDKITE_LABEL='Test Job'
  export BUILDKITE_BRANCH='main'
  export BUILDKITE_COMMIT='abc123def456'
  export BUILDKITE_MESSAGE='Test commit message'
  export BUILDKITE_AGENT_NAME='test-agent'
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
}

teardown() {
  unstub curl || true
  unstub buildkite-agent || true
}

@test "Missing integration-key fails" {
  unset BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_INTEGRATION_KEY

  run "$PWD"/hooks/pre-exit

  assert_failure 1
  assert_output --partial 'integration-key is required but not provided'
}

@test "No failure detected - skips incident creation" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'

  run "$PWD"/hooks/pre-exit

  assert_success
  refute_output --partial 'Creating PagerDuty incident'
}

@test "Job failure detected - creates incident" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Job failure detected'
  assert_output --partial 'creating PagerDuty incident'
  assert_output --partial 'PagerDuty incident workflow completed'
}

@test "Custom severity level - critical" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_SEVERITY='critical'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Job failure detected'
  assert_output --partial 'creating PagerDuty incident'
}

@test "Custom dedup key" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_DEDUP_KEY='custom-dedup-key-123'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"custom-dedup-key-123\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'creating PagerDuty incident'
}

@test "Check mode defaults to job" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Job failure detected'
}

@test "Skips execution when not in Buildkite environment" {
  unset BUILDKITE

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Not running in Buildkite environment'
}

@test "Check mode 'build' detects build failure" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='build'
  export BUILDKITE_AGENT_ACCESS_TOKEN='test-token'
  
  stub curl \
    '-s -f -H "Authorization: Bearer test-token" https://buildkite.com/test-org/test-pipeline/builds/123.json : echo "{\"state\":\"failed\"}"' \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Build failure detected'
  assert_output --partial 'creating PagerDuty incident'
}

@test "Check mode 'build' skips when build is passing" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='build'
  export BUILDKITE_AGENT_ACCESS_TOKEN='test-token'
  
  stub curl \
    '-s -f -H "Authorization: Bearer test-token" https://buildkite.com/test-org/test-pipeline/builds/123.json : echo "{\"state\":\"passed\"}"'

  run "$PWD"/hooks/pre-exit

  assert_success
  refute_output --partial 'creating PagerDuty incident'
}

@test "Check mode 'both' detects job failure" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='both'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Job failure detected'
  assert_output --partial 'creating PagerDuty incident'
}

@test "Check mode 'both' detects build failure when job passes" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='both'
  export BUILDKITE_AGENT_ACCESS_TOKEN='test-token'
  
  stub curl \
    '-s -f -H "Authorization: Bearer test-token" https://buildkite.com/test-org/test-pipeline/builds/123.json : echo "{\"state\":\"failing\"}"' \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Build failure detected'
  assert_output --partial 'creating PagerDuty incident'
}

@test "Severity 'warning' uses warning annotation style" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_SEVERITY='warning'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style warning --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'creating PagerDuty incident'
}

@test "Severity 'info' uses info annotation style" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_SEVERITY='info'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style info --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'creating PagerDuty incident'
}

@test "Handles PagerDuty API failure gracefully" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"error\",\"message\":\"Invalid routing key\"}"; echo "400"'
  
  stub buildkite-agent \
    "annotate --style warning --context pagerduty-error : echo 'Error annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_failure
  assert_output --partial 'Failed to create PagerDuty incident'
}

@test "Debug mode shows additional logging" {
  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_PLUGIN_DEBUG='true'
  
  stub curl \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Debug mode enabled'
  assert_output --partial '[DEBUG]'
}

@test "Build check handles missing BUILD_URL" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='build'
  unset BUILDKITE_BUILD_URL

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'BUILDKITE_BUILD_URL not available'
}

@test "Build check handles missing access token" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='build'
  unset BUILDKITE_AGENT_ACCESS_TOKEN

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'No API token available'
}

@test "Detects canceled build state as failure" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'
  export BUILDKITE_PLUGIN_INCIDENT_PAGERDUTY_CHECK='build'
  export BUILDKITE_AGENT_ACCESS_TOKEN='test-token'
  
  stub curl \
    '-s -f -H "Authorization: Bearer test-token" https://buildkite.com/test-org/test-pipeline/builds/123.json : echo "{\"state\":\"canceled\"}"' \
    '-s -w * -X POST https://events.pagerduty.com/v2/enqueue -H "Content-Type: application/json" -d * : echo "{\"status\":\"success\",\"dedup_key\":\"test-key\"}"; echo "202"'
  
  stub buildkite-agent \
    "annotate --style error --context pagerduty-incident-* : echo 'Annotation created'"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial 'Build failure detected'
  assert_output --partial 'creating PagerDuty incident'
}

