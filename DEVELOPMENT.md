# Development Setup Guide

This guide will help you set up a development environment for the GSMLG Platform Backend.

## Prerequisites

- **Elixir 1.14+** with Erlang/OTP 25+
- **PostgreSQL 13+**
- **Node.js 18+** (for frontend assets)
- **Bun 1.2.5+** (for JavaScript bundling)
- **Git**

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd gsmlg-app-backend
   ```

2. **Install dependencies**
   ```bash
   mix setup           # Install Elixir dependencies and setup database
   mix assets.setup    # Install frontend dependencies
   ```

3. **Setup database**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. **Start the development servers**
   ```bash
   mix phx.server      # Starts all applications (ports 4152 & 4153)
   ```

## Environment Variables

Create a `.env` file in the root directory with the following variables:

```bash
# Database Configuration
DB_USERNAME=gsmlg_app
DB_PASSWORD=your_secure_password
DB_HOST=localhost
DB_NAME=gsmlg_app_admin_dev

# Security Keys (generate new ones for production)
SECRET_KEY_BASE_WEB=your_secret_key_here
SECRET_KEY_BASE_ADMIN=your_secret_key_here
TOKEN_SIGNING_SECRET=your_token_secret_here

# Optional: Email Configuration
MAILER_FROM=noreply@yourdomain.com
MAILER_REPLY_TO=support@yourdomain.com
```

### Generating Secure Keys

Generate secure keys using:

```bash
# Generate secret key bases
mix phx.gen.secret
mix phx.gen.secret

# Generate token signing secret
openssl rand -base64 64
```

## Development Workflow

### Running Applications

- **All applications**: `mix phx.server` (ports 4152, 4153)
- **Admin only**: `mix phx.server -s gsmlg_app_admin` (port 4153)
- **Public only**: `mix phx.server -s gsmlg_app` (port 4152)

### Database Management

```bash
mix ecto.create          # Create database
mix ecto.migrate         # Run migrations
mix ecto.rollback        # Rollback last migration
mix ecto.reset          # Drop and recreate database
mix ecto.setup          # Create, migrate, and seed database
```

### Code Quality

```bash
mix format             # Format all code including HEEx files
mix test               # Run all tests
mix test --trace       # Run tests with detailed output
mix deps.clean --build # Clean and rebuild dependencies
```

### Frontend Assets

```bash
mix assets.setup       # Install frontend dependencies
mix assets.build       # Build assets for development
mix assets.deploy      # Build and minify for production
```

## Development Tools

### LiveDashboard
Access Phoenix LiveDashboard at: http://localhost:4153/dev/dashboard

### Email Preview
Access Swoosh mailbox preview at: http://localhost:4153/dev/mailbox

## Project Structure

```
gsmlg-app-backend/
├── apps/
│   ├── gsmlg_app/              # Core shared services
│   │   └── lib/
│   │       └── gsmlg_app/
│   │           ├── mailer.ex   # Email functionality
│   │           └── ...
│   ├── gsmlg_app_web/          # Public web interface (port 4152)
│   │   └── lib/
│   │       └── gsmlg_app_web/
│   │           ├── endpoint.ex
│   │           ├── router.ex
│   │           └── ...
│   ├── gsmlg_app_admin/        # Admin backend using Ash
│   │   └── lib/
│   │       └── gsmlg_app_admin/
│   │           └── accounts/
│   │               └── user/
│   │                   └── user.ex  # User resource
│   ├── gsmlg_app_admin_web/     # Admin web interface (port 4153)
│   │   └── lib/
│   │       └── gsmlg_app_admin_web/
│   │           ├── live/
│   │           │   └── user_management_live/
│   │           └── ...
│   └── gsmlg_app_component/     # Shared components
├── config/                     # Configuration files
├── priv/                       # Private files
└── test/                       # Test files
```

## Testing

### Running Tests

```bash
# Run all tests
mix test

# Run tests for specific app
mix test apps/gsmlg_app_admin/test/

# Run specific test file
mix test apps/gsmlg_app_admin/test/gsmlg_app_admin/accounts/user_test.exs

# Run specific test line
mix test apps/gsmlg_app_admin/test/gsmlg_app_admin/accounts/user_test.exs:25
```

### Test Coverage

```bash
# Generate test coverage report
mix test --cover

# View coverage details
open cover/excoveralls.html
```

## Common Issues

### Database Connection Issues

1. Ensure PostgreSQL is running
2. Check database credentials in `.env` file
3. Create the database user: `CREATE USER gsmlg_app WITH PASSWORD 'your_password';`

### Port Already in Use

```bash
# Find process using port 4152 or 4153
lsof -i :4152
lsof -i :4153

# Kill the process
kill -9 <PID>
```

### Asset Build Issues

```bash
# Clean and reinstall frontend dependencies
cd assets
rm -rf node_modules
bun install
cd ..
mix assets.build
```

## Production Deployment

### Building Releases

```bash
# Full backend release
mix release gsmlg_app_backend

# Admin-only release
mix release gsmlg_app_admin

# Public app release
mix release gsmlg_app
```

### Environment Variables for Production

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Secret key for Phoenix
- `PORT` - Server port (default: 4152)
- `HOST` - Host binding (default: localhost)

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `mix test`
5. Format code: `mix format`
6. Commit changes: `git commit -m "Add feature"`
7. Push to branch: `git push origin feature-name`
8. Open a Pull Request

## Code Style

- Follow Elixir conventions
- Use `mix format` for code formatting
- Write tests for new functionality
- Add module documentation (`@moduledoc`)
- Use meaningful variable and function names
- Keep functions small and focused

## Getting Help

- Check the [Phoenix documentation](https://hexdocs.pm/phoenix/overview.html)
- Check the [Ash Framework documentation](https://hexdocs.pm/ash/overview.html)
- Review existing code for patterns
- Ask questions in team channels