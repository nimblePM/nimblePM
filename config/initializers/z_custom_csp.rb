# Custom CSP configuration for Flowise integration
# This file starts with 'z_' to ensure it loads after the default CSP configuration

Rails.application.config.after_initialize do
  Rails.application.configure do
    config.content_security_policy do |policy|
      # Allow Flowise chat widget
      policy.connect_src "'self'", "https:", "wss:", "ws:", "https://ask.nimble.engineer", "https://*.nimble.engineer"
      policy.script_src  "'self'", "'unsafe-inline'", "'unsafe-eval'", "https:", "https://cdn.jsdelivr.net"
      policy.frame_src   "'self'", "https:", "https://ask.nimble.engineer"
      policy.img_src     "'self'", "https:", "data:", "blob:"
      policy.style_src   "'self'", "'unsafe-inline'", "https:"
      policy.font_src    "'self'", "https:", "data:"
    end
  end
end
