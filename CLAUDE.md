# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a forked OpenProject (Rails 8 + Angular) repository enhanced with AI chat capabilities via NimblePM Assistant. The stack runs via Docker with external PostgreSQL and includes Flowise chatbot integration.

## Essential Commands

### Docker Stack Management
Use `env.production` as the authoritative configuration source:

```bash
# Build and start (recommended)
sudo docker compose --env-file env.production up -d --build

# View logs
sudo docker compose --env-file env.production logs -f --tail=200

# Stop and remove containers
sudo docker compose --env-file env.production down

# Validate configuration
sudo docker compose --env-file env.production config
```

### Development Commands

**Backend (Rails):**
```bash
# Local Rails setup
bundle install && bin/rails db:setup

# Test suite
bundle exec rake test:suite:run
bundle exec rspec

# Linting
bundle exec lefthook install  # Pre-commit hooks
```

**Frontend (Angular):**
```bash
# Install dependencies (auto-run via root npm postinstall)
cd frontend && npm install

# Development server
npm run serve
# Or with public access: npm run serve:public

# Build for production
npm run build

# Testing
npm test                    # Run once
npm test:watch             # Watch mode

# Linting and type checking
npm run lint               # ESLint
npm run tslint_typechecks  # TypeScript checks
```

### Key Testing Commands
- **Full test suite**: `bundle exec rake test:suite:run`
- **RSpec only**: `bundle exec rspec`
- **Frontend tests**: `cd frontend && npm test`
- **Type checking**: `cd frontend && npm run tslint_typechecks`

## Architecture Overview

**Core Structure:**
- `app/`: Rails 8 backend (MVC, components)
- `frontend/`: Angular 20+ SPA with TypeScript
- `spec/`: RSpec test suite (feature, model, request specs)
- `config/`: Rails configurations, initializers
- `modules/`: OpenProject plugin extensions
- `public/`: Static assets, chat interfaces

**Chat Integration:**
- `worker.js`: Cloudflare Worker for popup chat
- `public/nimblepm-assistant.html`: Full-page chat interface
- `config/initializers/z_custom_csp.rb`: CSP overrides for external APIs
- External Flowise instance at `ask.nimble.engineer`

**Key Configuration:**
- `env.production`: Environment variables (Docker, DB, chat endpoints)
- `docker-compose.yml`: Container orchestration
- CSP configuration critical for chat functionality

## Development Guidelines

**Code Style:**
- Ruby: RuboCop rules (`.rubocop.yml`), 2-space indentation, double quotes
- TypeScript: ESLint, kebab-case files, strict typing
- ERB: erb_lint validation
- Line length: ~130 characters

**File Conventions:**
- Tests: `*_spec.rb` in `spec/` directory
- Factories: Use factory_bot over fixtures
- Components: Follow existing Angular patterns in `frontend/src/app/`

**Git Workflow:**
- Branch from `dev` (main development branch)
- Use `feature/<description>` or `hotfix/<id>` naming
- Reference work packages: `Refs OP#1234`
- Run linters/tests before committing

## Important Considerations

**CSP Configuration:**
Changes to `config/initializers/content_security_policy.rb` or `z_custom_csp.rb` require full container restart to take effect.

**Database:**
External PostgreSQL at 192.168.3.78 (configured in `env.production`)

**Security:**
- Never commit secrets to repository
- Use `env.production` for sensitive configuration
- CSP must allow external chat API connections

**Testing:**
- Always verify tests pass before changes
- Use request/feature specs for user flows
- Frontend tests use Jasmine/Karma

## MCP Integration

See `OpenProject_MCP_README.md` for Model Context Protocol server details and deployment instructions.

## Documentation References

- `AGENTS.md`: Repository-specific development conventions
- `AI_CHAT_INSTRUCTIONS.md`: Chat integration technical details and troubleshooting
- `README.md`: General OpenProject information and NimbleEngineer fork specifics