# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Faulty is an Elixir-based error tracking solution that provides a basic free error tracking service for applications. It's designed to be a requirement for almost any project to help provide quality and maintenance.

## Architecture

The project is structured as an Elixir library with these key components:

- **Main module**: `Faulty` - Core error reporting and context management
- **Application**: `Faulty.Application` - OTP application that starts automatically
- **Integrations**: Plug-and-play integrations for common Elixir/Phoenix stack:
  - `Faulty.Integrations.Phoenix` - Phoenix controllers and LiveViews via telemetry events
  - `Faulty.Integrations.Oban` - Background job error tracking via telemetry
  - `Faulty.Integrations.Plug` - Generic Plug-based applications
  - `Faulty.Integrations.Quantum` - Cron job scheduler integration
- **Schemas**: `Faulty.Error` and `Faulty.Stacktrace` - Data structures for error representation
- **Filtering**: `Faulty.Filter` and `Faulty.Ignorer` behaviors for customizing error handling
- **Reporter**: `Faulty.Reporter` - Handles sending errors to Faulty Tower

## Common Commands

### Testing
```bash
mix test                    # Run all tests
mix test test/specific_test.exs    # Run specific test file
mix test --only line        # Run test at specific line (add @tag line: true to test)
```

### Code Quality
```bash
mix format                  # Format all Elixir code using .formatter.exs
mix compile                 # Compile the project
mix deps.get               # Fetch dependencies
```

### Documentation
```bash
mix docs                   # Generate documentation (outputs to doc/)
```

### Installation Task
```bash
mix faulty.install         # Custom mix task to install Faulty in a project
```

## Development Notes

- **Requires Elixir 1.17+**
- **Dependencies**: Uses `Req` for HTTP requests, `Plug` for web integration, `Ecto` for schemas
- **Error Tracking**: Automatically tracks errors in Phoenix controllers, LiveViews, and Oban jobs via telemetry
- **Context System**: Supports per-process and per-call context for error enrichment
- **Configuration**: Configured via Application environment with keys like `:enabled`, `:retries`, `:connect_options`
- **Faulty Tower Integration**: Sends errors to accompanying Faulty Tower service for visualization

## Key Features

- Automatic error tracking for Phoenix/Plug/Oban applications
- Manual error reporting via `Faulty.report/2` and `Faulty.message/2` 
- Context enrichment system for adding custom data to errors
- Filtering and ignoring capabilities for unwanted errors
- Telemetry-based integrations requiring no code changes