# Change Log

All notable changes will be recorded in this filed.

## [v0.1.6](https://github.com/Hermanverschooten/faulty/compare/v0.1.5...v0.1.6) (2025-08-09)

### Added

- Error fingerprinting system for intelligent error grouping and deduplication
- Advanced error normalization for Erlang errors, TLS alerts, and Elixir exceptions
- Comprehensive test suite with 55+ tests covering core functionality
- Filter tests with examples for sanitizing passwords, credit cards, and emails
- Ignorer tests with patterns for development, throttling, and user-specific filtering
- Enhanced fingerprint generation with SHA256 hashing for consistent error identification

### Changed

- Improved error fingerprinting algorithm with better pattern recognition
- Enhanced test infrastructure with proper setup/cleanup and configuration management
- Updated dependencies

### Fixed

- Edge cases in fingerprint normalization for malformed error strings
- Improved handling of nested context sanitization in filters

## [v0.1.5](https://github.com/Hermanverschooten/faulty/compage/v0.1.4...v0.1.5) (2025-04-17)

* Removed `Web` module, was a left-over from `ErrorTracker`.

## [v0.1.4](https://github.com/Hermanverschooten/faulty/compage/v0.1.3...v0.1.4) (2025-04-10)

* Rewrote the igniter mix task to comply with the new style.
* Updated dependencies
* changed `igniter.install` option from `--env` to `--env_var`
* First released version

## [v0.1.3](https://github.com/Hermanverschooten/faulty/compage/v0.1.2...v0.1.3) (2025-03-27)

* Added ErrorHandler module to report on errors that are not logged by Telemetry events.
* Do not report the same error more than once.


## [v0.1.2](https://github.com/Hermanverschooten/faulty/compage/v0.1.2...v0.1.3) (2025-03-05)

* Updated dependencies


## v0.1.0

* Initial version with parts of [ErrorTracker](https://github.com/elixir-error-tracker/error-tracker)
