# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir umbrella project for the GSMLG platform backend, consisting of multiple applications that provide both public-facing services and administrative interfaces. The project uses Phoenix 1.8 with LiveView and the Ash Framework for data management.

## Applications Structure

- **`gsmlg_app`** - Core shared services (pubsub, mailer) - located at `apps/gsmlg_app/`
- **`gsmlg_app_web`** - Public web interface (port 4152) - located at `apps/gsmlg_app_web/`
- **`gsmlg_app_admin`** - Administrative backend using Ash framework - located at `apps/gsmlg_app_admin/`
- **`gsmlg_app_admin_web`** - Admin web interface with authentication (port 4153) - located at `apps/gsmlg_app_admin_web/`
- **`gsmlg_app_component`** - Shared Phoenix components library - located at `apps/gsmlg_app_component/`

## Essential Commands

### Development Setup
```bash
mix setup                    # Setup dependencies and database for all apps
mix assets.setup            # Install frontend dependencies (Tailwind, Bun)
mix assets.build            # Build frontend assets
```

### Running Applications
```bash
mix phx.server              # Start all applications
mix phx.server -s gsmlg_app_admin    # Start admin interface only (port 4153)
mix phx.server -s gsmlg_app          # Start public interface only (port 4152)
```

### Code Quality
```bash
mix format                   # Format all code including HEEx files
mix test                     # Run all tests
mix cmd mix test            # Run tests in all child apps
```

### Database Management (Admin App)
```bash
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset             # Drop and recreate database
mix ecto.setup             # Create, migrate, and seed database
```

### Testing
```bash
mix test                                     # Run all tests
mix test apps/app_name/test/specific_test.exs    # Run single test file
mix test apps/app_name/test/specific_test.exs:25 # Run specific test line
```

### Production
```bash
mix assets.deploy           # Build and minify assets for production
mix release gsmlg_app_backend   # Full backend release
mix release gsmlg_app_admin     # Admin-only release
mix release gsmlg_app           # Public app release
```

## Architecture Patterns

### Ash Framework Usage
- Resources are defined in `apps/gsmlg_app_admin/lib/gsmlg_app_admin/`
- Domains organize business logic
- Actions provide CRUD operations
- Policies handle authorization
- Uses `AshPostgres` for auto-generated migrations

### Phoenix LiveView Patterns
- HEEx templates for server-rendered HTML
- Components are in the `gsmlg_app_component` app
- Router pipelines for middleware (browser, API)
- LiveView for real-time web UI

### Database Configuration
- PostgreSQL 13+ required
- Development database: `gsmlg_app_admin_dev`
- Test database: `gsmlg_app_admin_test`
- Uses UUID primary keys with `uuid_generate_v4()` function
- Database user: `gsmlg_app` with password: `gsmlg_app`

## Development Environment

### Configuration Files
- `config/config.exs` - Base configuration
- `config/dev.exs` - Development settings with LiveDashboard at `/dev/dashboard`
- `config/test.exs` - Test configuration
- `config/runtime.exs` - Runtime configuration for secrets

### Key Development Features
- Live reload enabled in development
- Swoosh mailbox preview at `/dev/mailbox`
- Phoenix LiveDashboard at `/dev/dashboard`
- HTTP servers on ports 4152 (public) and 4153 (admin)

## Code Style Guidelines

Follow the established conventions:
- **Imports**: Group imports - stdlib, third-party, local apps
- **Formatting**: Use `mix format` (configured in .formatter.exs with Phoenix.LiveView.HTMLFormatter)
- **Types**: Use Elixir typespecs for public functions
- **Naming**: Snake_case for variables/functions, CamelCase for modules
- **Error Handling**: Use `with` statements and `{:ok, result}` / `{:error, reason}` tuples
- **Ash Framework**: Follow Ash resource conventions, use domains and actions
- **Phoenix**: Use HEEx templates, LiveView components, and proper router scoping

## Technology Stack

- **Elixir 1.14+** with Erlang/OTP 25+
- **Phoenix 1.8** with LiveView
- **Ash Framework 3.0** for data modeling
- **PostgreSQL** as primary database
- **Bandit** as HTTP server
- **Tailwind CSS 4.1.11** for styling
- **Bun 1.2.5** for JavaScript bundling
- **Swoosh** for email functionality

## Environment Variables for Production

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE_WEB` - Secret key for public web interface
- `SECRET_KEY_BASE_ADMIN` - Secret key for admin interface
- `TOKEN_SIGNING_SECRET` - Token signing secret for authentication
- `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_NAME` - Database credentials

## Docker Support

The project includes a multi-stage Dockerfile for production deployment. Build with:
```bash
docker build -t gsmlg-app-backend .
```

## Key Files Reference

- `mix.exs` - Umbrella project configuration with releases
- `devenv.nix` - Nix development environment with PostgreSQL
- `AGENTS.md` - Additional build/lint/test commands and code style guidelines
- `.formatter.exs` - Code formatting rules including HEEx files

## UI Framework

This app uses phoenix_duskmoon for UI instead of CoreComponents. phoenix_duskmoon is a Phoenix UI library that provides components and styling. The app uses duskmoonui instead of daisyui, where duskmoonui is a fork of daisyui that adds a tertiary color to the theme.