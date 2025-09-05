# Repository Guidelines

## Project Structure & Module Organization
- `app/`: Rails 8 application code (models, controllers, views, components).
- `frontend/`: Angular/TypeScript UI (installed via root `npm postinstall`).
- `spec/`: RSpec tests (feature, model, request, etc.).
- `config/`, `db/`, `public/`: Rails configs, migrations, assets.
- `modules/`: Optional plugins/extensions shipped with this fork.
- Orchestration: `docker-compose.yml`, `env.production` (authoritative), `Dockerfile.local`.
- Chat integration: `worker.js` (Cloudflare Worker), `public/nimblepm-assistant.html`.

## Build, Test, and Development Commands
- Docker (recommended):
  - Build/Up: `sudo docker compose --env-file env.production up -d --build`
  - Logs: `sudo docker compose --env-file env.production logs -f --tail=200`
  - Down: `sudo docker compose --env-file env.production down`
  - Validate: `sudo docker compose --env-file env.production config`
- Rails (local): `bundle install && bin/rails db:setup`
  - Test suite: `bundle exec rake test:suite:run` or `bundle exec rspec`
- Frontend: `npm test` or `npm run serve` (both run in `frontend/`).

## Coding Style & Naming Conventions
- Indentation: 2 spaces (`.editorconfig`).
- Ruby: RuboCop (`.rubocop.yml`), double-quoted strings, snake_case files, CamelCase classes.
- Views: ERB lint via `erb_lint`.
- Frontend: ESLint (see `lefthook.yml`), kebab-case file names, TypeScript strictness checked via `npm run tslint_typechecks` in `frontend/`.
- Keep lines concise (Rubocop LineLength ≈ 130).

## Testing Guidelines
- Framework: RSpec (see `spec/rails_helper.rb`).
- Naming: `*_spec.rb` in `spec/` (e.g., `spec/models/user_spec.rb`).
- Run all: `bundle exec rake test:suite:run`.
- Frontend: `cd frontend && npm test`.
- Prefer factories (`factory_bot`) and request/feature specs for user flows.

## Commit & Pull Request Guidelines
- Branch from `dev`; use `feature/<short-description>` or `hotfix/<id>`.
- Commits: clear, imperative subject; reference issues/work packages (e.g., `Refs OP#1234`).
- PRs: include intent, scope, test coverage notes, screenshots for UI, and linked issue.
- Ensure linters/tests pass locally. Pre-commit hooks via `bundle exec lefthook install`.

## Security & Configuration Tips
- Do not commit secrets; use `env.production` and per-service `env_file` entries.
- CSP: overrides live in `config/initializers/z_custom_csp.rb` (match domains used by chat/Flowise/CDNs).
- Database and external endpoints must align with `env.production`. Restart containers after initializer changes.

