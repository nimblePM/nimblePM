## AI Chat Instructions

Purpose: Give AI assistants and humans a single, canonical place to find the exact commands and conventions for running this forked OpenProject stack and related MCP components.

### Canonical commands: OpenProject via docker compose using env.production

Use env.production as the source of configuration when running the stack.

Docker Compose v2 (recommended):

```bash
sudo docker compose --env-file env.production build
sudo docker compose --env-file env.production up -d
# view logs
sudo docker compose --env-file env.production logs -f --tail=200
# stop and remove
sudo docker compose --env-file env.production down
# rebuild and start in one go
sudo docker compose --env-file env.production up -d --build
# validate merged config
sudo docker compose --env-file env.production config
```

Legacy docker-compose binary (if present):

```bash
sudo docker-compose --env-file env.production build
sudo docker-compose --env-file env.production up -d
sudo docker-compose --env-file env.production logs -f --tail=200
sudo docker-compose --env-file env.production down
sudo docker-compose --env-file env.production up -d --build
sudo docker-compose --env-file env.production config
```

Notes:
- env.production is intentionally kept in-repo for now at the user's request; treat it as authoritative for local/prod-like runs of this fork.
- The compose file may reference a service-level env_file; ensure values in env.production mirror any file referenced there.

### MCP server notes

- See `OpenProject_MCP_README.md` for capabilities and deployment details.
- If an MCP container is used, keep its database connection values aligned with env.production.

### AI assistant update protocol

When assisting in this repository, follow these rules:
- Treat this file as the authoritative runbook for commands affecting how the stack is built/started/stopped.
- Whenever a new command, flag, environment variable, or convention is discovered or changed, update the relevant section here immediately.
- Maintain the "Session notes" log below with timestamped bullets for notable changes, discoveries, or caveats. Keep entries concise and high-signal.
- Do not store secrets. If sensitive values are needed, reference them generically (e.g., DB_PASSWORD) and point to env.production.

### Session notes

- 2025-09-04: Initial version added with canonical docker compose commands using env.production.


