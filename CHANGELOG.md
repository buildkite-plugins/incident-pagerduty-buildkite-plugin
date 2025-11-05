# Changelog

All notable changes to this project will be documented in this file.

## v1.0.0 - 2025-11-05

### Added

- Initial release of the Incident PagerDuty Buildkite Plugin.
- Automatic incident creation for failed jobs (`check: job`) and failed builds (`check: build`).
- Configurable severity, deduplication key, and soft-fail exit statuses.
- Buildkite annotations containing PagerDuty incident context and links.
- Shared logging utilities and failure detection helpers.

### Documentation

- Comprehensive README covering required/optional options, examples, compatibility, and contributing guidelines.
