# Agent Guidelines for GSMLG App Backend

This repo is an Elixir umbrella with multiple apps under `apps/`.
Use umbrella-level commands from the repo root unless noted.
If you run commands from an app subdirectory, use that app's `mix.exs`.

## Build/Lint/Test Commands

### General Setup
- `mix setup` - Run setup in all child apps (umbrella alias)
- `mix deps.get` - Fetch umbrella dependencies
- `mix cmd mix deps.get` - Fetch deps in every app
- `mix phx.server` - Start all apps (ports 4152/4153)
- `mix phx.server -s gsmlg_app` - Start public app only
- `mix phx.server -s gsmlg_app_admin` - Start admin app only

### Formatting
- `mix format` - Format all code and HEEx templates (umbrella)
- `mix format apps/gsmlg_app_web/lib/**/*.ex` - Format a subset

### Linting / Static Analysis
- `mix lint` - Run lint in all child apps (umbrella alias)
- `mix cmd mix lint` - Same as above, explicit umbrella run
- `mix credo --strict` - Run Credo in current app
- `mix dialyzer` - Run Dialyzer in current app

### Testing
- `mix test` - Run all tests (umbrella)
- `mix cmd mix test` - Run tests for every child app
- `mix test apps/gsmlg_app/test/` - Run tests for a specific app
- `mix test apps/gsmlg_app_admin/test/path/to_test.exs` - Run single test file
- `mix test apps/gsmlg_app_admin/test/path/to_test.exs:25` - Run single test line
- `mix test --trace` - Verbose test output
- `mix test --cover` - Coverage report (writes `cover/`)

### Database (Admin App)
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run migrations
- `mix ecto.rollback` - Roll back last migration
- `mix ecto.reset` - Drop and recreate database
- `mix ecto.setup` - Create, migrate, seed

### Assets (Web Apps)
- `mix assets.setup` - Install Tailwind/Bun
- `mix assets.build` - Build assets for development
- `mix assets.deploy` - Build/minify assets for production
- `mix phx.digest` - Digest static assets (run by deploy)

### Releases
- `mix release gsmlg_app_backend` - Build full release
- `mix release gsmlg_app_admin` - Build admin-only release
- `mix release gsmlg_app` - Build public-only release

### Release Database Commands
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.migrate"` - Run migrations
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.create"` - Create database
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.seed"` - Run seeds
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.setup"` - Create + migrate + seed
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.migration_status"` - Check migration status
- `bin/gsmlg_app_backend eval "GsmlgAppAdmin.Release.rollback(GsmlgAppAdmin.Repo, VERSION)"` - Roll back to version

## Code Style Guidelines

### Formatting
- Always run `mix format` before finalizing changes.
- Root `.formatter.exs` imports Phoenix/Ash formatting and HEEx support.
- Keep line wrapping consistent with formatter output.

### Imports, Aliases, and Requires
- Prefer `alias` over `import` for clarity.
- Use `import` only for small, well-scoped helpers.
- Group aliases by namespace and keep sorted alphabetically.
- Avoid wildcard imports unless a file already uses that pattern.

### Typespecs and Documentation
- Add `@spec` for public functions.
- Add `@doc` for public functions and `@moduledoc` for public modules.
- Keep types in `typespec` modules when shared across contexts.

### Naming Conventions
- `snake_case` for functions, variables, and atoms.
- `CamelCase` for modules.
- Use `?` suffix for boolean predicates.
- Use `!` suffix only for functions that may raise.

### Error Handling
- Use `with` to chain multi-step operations.
- Return `{:ok, result}` / `{:error, reason}` tuples for fallible paths.
- Prefer pattern matching and `case` over nested conditionals.
- Avoid `raise` outside of boundary layers (e.g., CLI or tasks).

### Elixir Style
- Keep functions short and focused.
- Prefer pattern matching in function heads.
- Use `Logger` for diagnostics instead of `IO.inspect`.
- Do not introduce one-letter variable names.

### Phoenix / LiveView
- Use HEEx templates for rendering.
- Keep LiveView state in `assigns` and reduce side effects.
- Use `Phoenix.Component` and `Phoenix.LiveView` conventions.
- Keep router scopes consistent with existing routes.

### Ash Framework
- Follow resource/action conventions (`read`, `create`, `update`, `destroy`).
- Keep Ash resources in `gsmlg_app_admin` and domain modules in `lib/`.
- Use `Ash.Changeset` for validations and constraints.
- Prefer policies and actions over custom Ecto queries.

### Ecto / Database
- Use `Ecto.Multi` for multi-step transactions.
- Keep migrations idempotent and reversible.
- Use `Repo` calls at boundary layers, not in pure helpers.

### Components and UI
- Shared UI lives in `gsmlg_app_component`.
- Reuse components instead of duplicating markup.
- Keep HEEx component APIs consistent across apps.

### Testing
- Use ExUnit with descriptive test names.
- Favor `async: true` when tests are isolated.
- Use `test/support` helpers for setup and factories.
- Keep test data explicit and close to the test case.

### Configuration
- Use `config/*.exs` for environment defaults.
- Runtime secrets live in `config/runtime.exs` and environment variables.
- Avoid hardcoding secrets or ports in code.

### Logging and Telemetry
- Prefer structured `Logger` metadata for diagnostics.
- Use `Logger` levels consistently (`debug`, `info`, `warn`, `error`).
- Keep telemetry wiring near web endpoints and LiveView hooks.

### Security and Secrets
- Load secrets from environment variables or `config/runtime.exs`.
- Avoid committing `.env` files or credentials.
- Use strong secrets for key bases and token signing.

### Dependencies
- Use `in_umbrella: true` for local app deps.
- Add deps in the owning app's `mix.exs`.

## Repo Structure Tips
- Umbrella apps live in `apps/` with shared deps in root.
- App-specific assets tasks live in each app's `mix.exs`.
- Shared components live in `apps/gsmlg_app_component`.

## Cursor / Copilot Rules
- No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` files were found.

## Agent Notes
- Keep changes focused to the requested task.
- Follow existing patterns in the app you touch.
- Run the most specific tests possible before full suite.
- Do not add new tooling without team approval.
