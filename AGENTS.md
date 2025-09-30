# Agent Guidelines for Gsmlg App Backend

## Build/Lint/Test Commands
- `mix format` - Format all code using .formatter.exs rules
- `mix test` - Run all tests (includes DB setup for apps with Ecto)
- `mix test apps/app_name/test/path/to_test.exs` - Run single test file
- `mix test apps/app_name/test/path/to_test.exs:line` - Run specific test line
- `mix cmd mix test` - Run tests in all child apps
- `mix setup` - Setup dependencies and DB for all apps

## Code Style Guidelines
- **Imports**: Group imports: stdlib, third-party, local apps
- **Formatting**: Use `mix format` (configured in .formatter.exs)
- **Types**: Use Elixir typespecs for public functions
- **Naming**: Snake_case for variables/functions, CamelCase for modules
- **Error Handling**: Use `with` statements, `{:ok, result}` / `{:error, reason}` tuples
- **Ash Framework**: Follow Ash resource conventions, use domains and actions
- **Phoenix**: Use HEEx templates, LiveView components, and proper router scoping