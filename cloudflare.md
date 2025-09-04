## This is the code I have running as a worker in cloudflare, route attached to nimble.engineer/* and it adds the MCP capability from flowise which talks to the MCP server (which both flowise and openproject_mcp dockers are currently hosted as a docker containers on this VM's host unraid server)

export default {
  async fetch(request, env, ctx) {
    const response = await fetch(request);

    // Pass through non-HTML responses
    const contentType = response.headers.get('content-type');
    if (!contentType || !contentType.includes('text/html')) {
      return response;
    }

    const rewriter = new HTMLRewriter();

    // This handler finds the meta tag with the nonce and saves the value
    // on the rewriter instance so the next handler can use it.
    rewriter.on('meta[name="csp-nonce"]', {
      element(element) {
        rewriter.nonce = element.getAttribute('content');
      },
    });

    // This handler runs on the <body> tag
    rewriter.on('body', {
      element(element) {
        // Use the nonce we found, or an empty string if none exists
        const nonceAttribute = rewriter.nonce ? `nonce="${rewriter.nonce}"` : '';

        const chatScript = `
          <script type="module" ${nonceAttribute}>
            import Chatbot from "https://cdn.jsdelivr.net/npm/flowise-embed/dist/web.js"
            Chatbot.init({
                chatflowid: "e2dfade6-7e37-4fd9-bdae-fb40b614e126",
                apiHost: "https://ask.nimble.engineer",
                theme: {
                    button: {
                        backgroundColor: "#6366F1",
                        right: 20,
                        bottom: 20,
                        size: 'large',
                        zIndex: 9999
                    },
                    chatWindow: {
                        zIndex: 9999
                    }
                }
            })
          </script>
        `;
        element.append(chatScript, { html: true });
      }
    });

    return rewriter.transform(response);
  },
};

## Cloudflared Tunnels 

Currently this VM is accessed via ~/.cloudflared/config.yml and it has various endpoints for ssh, ask (flowise), mcp (but i don't think that subdomain is used), and probably more to come.