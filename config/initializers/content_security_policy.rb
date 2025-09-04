Rails.application.config.after_initialize do
  Rails.application.configure do
    config.content_security_policy do |policy|
      # Set a less restrictive "Allow any HTTPS" policy
      policy.base_uri    "'self'"
      policy.connect_src "'self'", "https:", "wss:"
      policy.default_src "'self'", "https:"
      policy.font_src    "'self'", "https:", "data:"
      policy.form_action "'self'", "https:"
      policy.frame_ancestors "'self'"
      policy.img_src     "'self'", "https://*", "data:", "blob:"
      policy.script_src  "'self'", "'unsafe-inline'", "'unsafe-eval'", "https:"
      policy.style_src   "'self'", "'unsafe-inline'", "https:"
      # The nonce generator below will be used instead of the one previously here.
    end

    # Generate session nonces for permitted importmap, inline scripts, and inline styles.
    # This handles Turbo integration natively
    config.content_security_policy_nonce_generator = lambda do |request|
      # Use Turbo nonce if available (for Turbo navigation)
      if request.env["HTTP_TURBO_REFERRER"].present? && request.env["HTTP_X_TURBO_NONCE"].present?
        request.env["HTTP_X_TURBO_NONCE"]
      else
        # Generate a new nonce based on session
        SecureRandom.base64(16)
      end
    end

    config.content_security_policy_nonce_directives = %w(script-src)
  end
end
