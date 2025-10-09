# GSMLG App Backend

A comprehensive Elixir umbrella application providing both public-facing services and administrative interfaces for the GSMLG platform.

## Architecture

This is an Elixir umbrella project consisting of multiple applications:

### Applications

- **`gsmlg_app`** - Core application providing shared services (pubsub, mailer)
- **`gsmlg_app_web`** - Public web interface with informational pages and WHOIS lookup API
- **`gsmlg_app_admin`** - Administrative backend using Ash framework for data management
- **`gsmlg_app_admin_web`** - Admin web interface with authentication and management UI
- **`gsmlg_app_component`** - Shared Phoenix components library

### Technology Stack

- **Elixir 1.14+** - Core language and OTP
- **Phoenix 1.8** - Web framework
- **Phoenix LiveView** - Real-time web UI
- **Ash Framework** - Data modeling and management
- **PostgreSQL** - Primary database (admin app)
- **Bandit** - HTTP server
- **Tailwind CSS** - Styling
- **Bun** - JavaScript bundler
- **Swoosh** - Email library

## Features

### Public Interface (`gsmlg_app_web`)
- Informational pages (home, about, support)
- Apps listing and support/privacy information
- WHOIS lookup API for domains, IPs, and AS numbers
- Geographic mapping for clips

### Admin Interface (`gsmlg_app_admin_web`)
- User authentication and management
- Blog post management
- Administrative dashboard
- Ash-based data management

## Prerequisites

- Elixir 1.14+
- Erlang/OTP 25+
- PostgreSQL 13+
- Node.js (for assets)
- Bun 1.0+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/gsmlg-dev/gsmlg-app-backend.git
cd gsmlg-app-backend
```

2. Install dependencies and setup the database:
```bash
mix setup
```

3. Install frontend dependencies:
```bash
mix assets.setup
```

4. Build frontend assets:
```bash
mix assets.build
```

## Development

### Starting the Development Server

Start all applications:
```bash
mix phx.server
```

Or start specific releases:
```bash
# Admin interface (default port 4000)
mix phx.server -s gsmlg_app_admin

# Public interface (default port 4001)  
mix phx.server -s gsmlg_app
```

### Available Commands

#### General Commands
- `mix format` - Format all code (including HEEx files)
- `mix test` - Run all tests
- `mix cmd mix test` - Run tests in all child apps
- `mix setup` - Setup dependencies and database for all apps

#### Asset Commands
- `mix assets.setup` - Install frontend dependencies
- `mix assets.build` - Build frontend assets
- `mix assets.deploy` - Build and minify assets for production

#### Database Commands (Admin App)
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run migrations
- `mix ecto.reset` - Drop and recreate database
- `mix ecto.setup` - Create, migrate, and seed database

#### Testing
- `mix test` - Run all tests
- `mix test apps/app_name/test/path/to_test.exs` - Run single test file
- `mix test apps/app_name/test/path/to_test.exs:line` - Run specific test line

## Configuration

Configuration files are located in the `config/` directory:
- `config.exs` - Base configuration
- `dev.exs` - Development environment
- `prod.exs` - Production environment
- `runtime.exs` - Runtime configuration

### Environment Variables

Key environment variables for production:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Secret key for Phoenix
- `PORT` - Server port (default: 4152)

## Deployment

### Docker

The project includes a multi-stage Dockerfile for production deployment:

```bash
# Build image
docker build -t gsmlg-app-backend .

# Run container
docker run -p 4152:4152 \
  -e DATABASE_URL="ecto://user:pass@host/db" \
  -e SECRET_KEY_BASE="your-secret-key" \
  gsmlg-app-backend
```

### Releases

Create production releases:
```bash
# Full backend release
mix release gsmlg_app_backend

# Admin-only release
mix release gsmlg_app_admin

# Public app release
mix release gsmlg_app
```

## Project Structure

```
├── apps/
│   ├── gsmlg_app/                 # Core application
│   ├── gsmlg_app_web/             # Public web interface
│   ├── gsmlg_app_admin/           # Admin backend
│   ├── gsmlg_app_admin_web/       # Admin web interface
│   └── gsmlg_app_component/       # Shared components
├── config/                        # Configuration files
├── rel/                          # Release configuration
└── .github/workflows/            # CI/CD workflows
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure code formatting:
   ```bash
   mix format
   mix test
   ```
5. Submit a pull request

## License

This project is licensed under the MIT License.