# Change Log

All notable changes will be recorded in this filed.

## Unreleased

### Added

- `Faulty.clear_reported/0` to reset the duplicate-report guard of the current process, for long-lived processes such as a `GenServer` that rescue and report errors.

### Fixed

- A process no longer stops reporting after its first error: the duplicate-report guard is now cleared at the start of every Phoenix request, LiveView mount and `handle_params`, Oban job and Quantum job.
- The Plug integration's own per-process guard is cleared the same way, so a keep-alive connection process reports more than its first router exception.
- Errors that are a term without a `String.Chars` implementation (for example `throw(%{code: 42})`) are now stored with `inspect/1` of the term instead of the literal `"Term"`.

## [v0.1.10](https://github.com/Hermanverschooten/faulty/compare/v0.1.9...v0.1.10) (2026-09-08)

### Security

- Updated `mint` 1.9.3 → 1.10.0, addressing CVE-2026-82728 (HTTP/1 status-line/chunk-extension memory-exhaustion DoS) and CVE-2026-82729 (chunked response chunk-size CPU-exhaustion DoS)

### Changed

- Updated dependencies: req 0.6.3 → 0.7.4, ecto 3.14.1 → 3.14.2, ex_doc 0.40.3 → 0.40.4, igniter 0.8.3 → 0.8.4, mint 1.9.3 → 1.10.0, spitfire 0.3.13 → 0.4.1

## [v0.1.9](https://github.com/Hermanverschooten/faulty/compare/v0.1.8...v0.1.9) (2026-07-26)

### Fixed

- Removed a stray `dbg()` call in `Faulty.LoggerHandler` that printed debug output to stdout every time an exception was reported. Present since v0.1.3.

### Security

- Updated `mint` 1.9.0 → 1.9.3, addressing CVE-2026-59249 (HTTP/1 chunk-size request smuggling), CVE-2026-58229 (unbounded response header size) and CVE-2026-59246 (empty HTTP/2 CONTINUATION frames)
- Updated `hpax` 1.0.3 → 1.0.4, addressing CVE-2026-58226 (unbounded HPACK integer decoding DoS)
- Updated `plug` 1.19.2 → 1.20.3, addressing CVE-2026-56814 (multipart parts not counted towards the length limit) and CVE-2026-56813 (semicolon injection in cookie attributes)

### Changed

- Updated dependencies: req 0.6.1 → 0.6.3, plug 1.19.2 → 1.20.3, ecto 3.14.0 → 3.14.1, igniter 0.8.1 → 0.8.3, finch 0.22.0 → 0.23.0, mint 1.9.0 → 1.9.3, hpax 1.0.3 → 1.0.4, plug_crypto 2.1.1 → 2.2.0, sourceror 1.12.0 → 1.12.2, ex_ast 0.12.0 → 0.13.1, glob_ex 0.1.11 → 0.1.12, makeup 1.2.1 → 1.2.2, earmark_parser 1.4.44 → 1.4.46

## [v0.1.8](https://github.com/Hermanverschooten/faulty/compare/v0.1.7...v0.1.8) (2026-06-13)

### Changed

- Updated dependencies: ecto 3.13.5 → 3.14.0, req 0.5.17 → 0.6.1, plug 1.19.1 → 1.19.2, ex_doc 0.40.1 → 0.40.3, igniter 0.7.2 → 0.8.1, finch 0.21.0 → 0.22.0, mint 1.7.1 → 1.9.0, decimal 2.3.0 → 3.1.1, telemetry 1.3.0 → 1.4.2, and other transitive deps

### Fixed

- Resolved compiler warnings under Elixir 1.20 / OTP 29 (unused `require Logger`, unreachable filter test clauses)

## [v0.1.7](https://github.com/Hermanverschooten/faulty/compare/v0.1.6...v0.1.7) (2026-02-03)

### Changed

- Updated ecto 3.13.2 → 3.13.5
- Updated ex_doc 0.38.2 → 0.40.1
- Updated igniter 0.6.25 → 0.7.2
- Updated plug 1.18.1 → 1.19.1
- Updated req 0.5.15 → 0.5.17

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
