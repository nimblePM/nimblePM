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
- 2025-09-05: Homepage chat height fix — single height anchor on `#content` with overlay layout (hero and chat `position: absolute; inset: 0`) to prevent push-down and scrolling after transition; remove hero from layout post-transition.

## nimblePM Chatbot Integration - Technical Summary

### Setup & Architecture

**Current Infrastructure:**
- **Base**: OpenProject 16-slim fork running in Docker containers
- **Deployment**: Docker Compose with volume mounts for custom file overlays
- **Database**: External PostgreSQL 17 at 192.168.3.78
- **Domain**: nimble.engineer (HTTPS via Cloudflare)
- **Backend**: Custom Flowise instance at ask.nimble.engineer
- **Popup Chat**: Cloudflare Worker (worker.js) injecting popup chatbot on non-homepage routes

**File Architecture:**
```
nimbleengineer/
├── docker-compose.yml              # Container orchestration
├── env.production                  # Environment variables & CSP config
├── worker.js                       # Cloudflare Worker for popup chat
├── public/nimblepm-assistant.html  # Full-page chatbot interface
├── public/simple-chat.html         # Minimal test interface
├── app/views/homescreen/index.html.erb    # Homepage view (iframe container)
├── app/controllers/homescreen_controller.rb # Simplified controller
└── config/initializers/
    ├── content_security_policy.rb  # OpenProject's default CSP
    └── z_custom_csp.rb             # Our CSP overrides
```

### Intent & Goals

**Primary Objective:**
Create a beautiful homepage chatbot experience with:
1. **Hero Landing Page**: Large, professional interface with:
   - "nimblePM Assistant" branding
   - Search input field
   - Quick action buttons ("Summarize project updates", etc.)
   - NS Power T&D Engineering branding

2. **Smooth Transition**: When user interacts:
   - Hero interface smoothly animates away
   - Full-screen chatbot interface appears
   - Initial message is automatically sent

3. **Persistent Chat**: Chatbot should:
   - Stay visible after sending messages (no blank screen)
   - Handle conversations properly
   - Work without popup interference

**User Experience Flow:**
```
Landing Page → User Click/Type → Smooth Transition → Full Chatbot → Persistent Chat
```

### Technical Challenges & Solutions

**Phase 1: Initial Implementation Issues**
- ❌ **Problem**: Chatbot disappeared after first message (blank white screen)
- 🔧 **Attempted**: Various Flowise initialization methods (`initFull()`, `init()`)
- 🔧 **Attempted**: DOM manipulation to move chatbot elements
- 🔍 **Discovery**: Console showed chatbot was being created but with broken CSS

**Phase 2: CSS/Layout Debugging**
- ❌ **Problem**: Chatbot only visible when zooming out (CSS dimension issue)
- 🔧 **Attempted**: Multiple CSS fixes for `flowise-fullchatbot` sizing
- 🔧 **Attempted**: Force absolute positioning and pixel dimensions
- 🔍 **Discovery**: Invalid CSS `calc(-80px + 100vh)` causing layout issues

**Phase 3: Content Security Policy (CSP) Issues**
- ❌ **Problem**: CSP blocking Flowise CDN and API connections
- 🔧 **Attempted**: Environment variable CSP configuration
- 🔧 **Attempted**: Docker environment variable passing
- 🔍 **Discovery**: OpenProject's built-in CSP overriding our settings

### Key Technical Insights

1. **CSP is Critical**: External integrations require careful CSP configuration
2. **OpenProject Customization**: Requires understanding of Rails initializer loading order
3. **Flowise Complexity**: Different initialization methods have different reliability
4. **CSS Layout Issues**: Web components can have unexpected sizing behaviors
5. **Docker Development**: Volume mounts enable rapid iteration without rebuilds

### Current CSP Fix Required

The core issue is **Content Security Policy blocking external connections**. Fix by editing `config/initializers/content_security_policy.rb`:

```ruby
policy.connect_src "'self'", "https:", "http:", "wss:", "ws:", "https://ask.nimble.engineer"
policy.script_src  "'self'", "'unsafe-inline'", "'unsafe-eval'", "https:", "https://cdn.jsdelivr.net"
policy.frame_src   "'self'", "https:", "https://ask.nimble.engineer"
```

### Success Criteria

- [ ] No CSP errors in browser console
- [ ] Full-page chatbot loads and displays properly
- [ ] Smooth transition from hero to chat interface
- [ ] Initial message automatically sent
- [ ] Chatbot remains visible after sending messages
- [ ] Professional branding and UX maintained

### Architecture Decisions Made

1. **Volume Mount Approach**: ✅ Allows easy file updates without rebuilding base image
2. **Iframe Embedding**: ✅ Isolates chatbot from OpenProject's CSS/JS
3. **Cloudflare Worker**: ✅ Provides popup chat on other pages
4. **Custom CSP**: ✅ Required for external API connections

**Note**: Changes to CSP initializers require full container restart (`down` then `up`) to reload Rails initializers.
