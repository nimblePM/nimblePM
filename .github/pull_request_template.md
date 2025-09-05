Title: <short imperative summary>

## Summary
- What does this change and why?

## Type
- [ ] Feature
- [ ] Fix
- [ ] Refactor
- [ ] Chore
- [ ] Docs

## Linked Issues
- Closes #
- Refs OP# (work package)

## Screenshots / GIF (optional)

## Test Plan
- Backend: `bundle exec rake test:suite:run`
- Frontend: `cd frontend && npm test`
- Docker config: `sudo docker compose --env-file env.production config`

## Checklist
- [ ] Linters pass (Rubocop/ERB/ESLint) locally or via lefthook
- [ ] Tests pass (backend + frontend) locally
- [ ] Docs updated if needed (AGENTS.md, AI_CHAT_INSTRUCTIONS.md)
- [ ] No secrets committed; config via `env.production`
- [ ] CSP updated if new external endpoints (see `config/initializers/z_custom_csp.rb`)
- [ ] UI changes include screenshots
- [ ] DB migrations (if any) are reversible and reviewed
- [ ] Docker Compose changes validated with `env.production`

