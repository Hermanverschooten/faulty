# Change Log

All notable changes will be recorded in this filed.

## Unreleased

### Added

- `Faulty.clear_reported/0` to reset the duplicate-report guard of the current process, for long-lived processes such as a `GenServer` that rescue and report errors.

### Changed

- The JSON library is now configurable with `:json_library` and defaults to the `JSON` module that is part of Elixir 1.18+. Any module that exports `encode!/1` works. `jason` is now an optional dependency: on Elixir 1.17 add it and set `config :faulty, json_library: Jason`, `mix faulty.install` does this for you. The library is checked when Faulty starts.
- Errors are sent as plain data, `Faulty.Error`, `Faulty.Stacktrace` and its lines no longer implement `Jason.Encoder`. The JSON that is sent is unchanged. Values in the error context must be encodable by the configured library (`@derive JSON.Encoder` instead of `@derive Jason.Encoder` for your own structs on the built-in `JSON`).
- An error whose context cannot be encoded is dropped with a warning in your logs, instead of silently.
- Removed the `ecto` (and its `decimal`) dependency: `Faulty.Error` and `Faulty.Stacktrace` are now plain structs with the same fields and the same JSON shape, `Faulty.Error.new/3` and `Faulty.Stacktrace.new/1` still return `{:ok, struct}`. `telemetry` is now an explicit dependency, it was already pulled in indirectly.
- `plug` is now an optional dependency. The `Faulty.Integrations.Plug` and `Faulty.Integrations.Phoenix` integrations are only compiled when Plug is available, which it always is in a Phoenix application.
- The error context is now scrubbed by default: the value under a sensitive key (`password`, `token`, `secret`, `authorization`, `x-api-key`, `cookie`, ...) is replaced by `"[FILTERED]"` before your `Faulty.Filter` runs. See `Faulty.Scrubber`. Set `config :faulty, scrub_pii: false` to turn it off.
- Errors are now sent from a supervised `Task`, one at a time, so a slow or unreachable FaultyTower no longer blocks the reporter.
- The queue of errors waiting to be sent is limited by the new `:queue_size` option (default 1000). New errors are dropped while it is full.
- Only network errors and `408`, `429` and `5xx` responses are retried, after `:retry_interval` (default one minute). Any other non-2xx response drops the error instead of blocking the queue behind it forever.
- The FaultyTower url is read when an error is sent, and an error is dropped when it is not set, instead of crashing the reporter.
- **Breaking:** errors are now sent with Erlang's built-in `:httpc` and `Req` is no longer a dependency, which removes `req`, `finch`, `mint`, `hpax`, `nimble_pool`, `nimble_options` and `mime` from your dependency tree. The certificate of FaultyTower is still verified against your system's CA certificates.
- `:connect_options` keeps working for the keys `:transport_opts` (the `:ssl` options, so the `transport_opts: [verify: :verify_none]` that `mix faulty.install` writes to `dev.exs` still works), `:timeout` (the connect timeout) and `:proxy` (`{:http, host, port, []}`). Other keys are ignored and a warning is logged at startup.
- **Breaking:** the `:retries` and `:req_options` options are no longer used, a warning is logged at startup when they are set. Failed errors are retried by the queue, see `:retry_interval`.
- New `:receive_timeout` option, the longest a single request may take, defaults to 15 seconds.
- A request that fails because the `:httpc` process is not available is retried instead of dropped.

### Fixed

- The documented `mix faulty.install --env_var URL_VAR` was silently ignored, only `--env-var` is recognized. The docs now use `--env-var`.
- `Faulty.Stacktrace.source/1` now finds the first stack line that belongs to your `:otp_app`. It compared the application name (a string) with the configured atom, so it never matched and always returned the first line, usually library code. The source line and function of new errors, which are part of their fingerprint, now point at your own code. **Errors reported from a stack that starts in library code will get a new fingerprint and show up as new groups in FaultyTower.**
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
