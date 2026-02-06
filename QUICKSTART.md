# QUICKSTART.md

Get OpenClaw + Emacs running in 5 minutes.

## Prerequisites

- Emacs (with your current config from ~/.emacs.d/init.el)
- Python 3.10+
- Google account (for OAuth)

## 1. Server Setup (One-time)

### Get OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or use existing)
3. Enable these APIs:
   - Gmail API
   - Google Calendar API
4. Create "OAuth 2.0 Client ID" → Desktop application
5. Download JSON credentials
6. Save as: `server/client_secret.json`

### Install Dependencies

```bash
cd ~/repos/emacs-openclaw/server
pip install -r requirements.txt
```

### First Run (Authenticate) - OPTIONAL

The server will auto-start when you use Emacs, but you can pre-authenticate:

```bash
cd ~/repos/emacs-openclaw
./start-server.sh
```

This will:
- Open your browser for OAuth consent (first time only)
- Save token to `server/token.json`
- Start server on `http://127.0.0.1:3333`

Press Ctrl+C to stop after authentication if you want to let Emacs manage it.

## 2. Test in Emacs

In a fresh Emacs session:

```elisp
M-x emacs-openclaw-chat
```

The server will auto-start if not running (requires `client_secret.json` to be set up).

You should see a `*OpenClaw-Chat*` buffer. Type a message and press RET.

## 3. Discover Available Tools

Check what Gmail/Calendar tools are available:

```elisp
M-x emacs-openclaw-get-available-tools
```

This will:
- Fetch available tools from the server
- Display them in a `*OpenClaw-Tools*` buffer
- Save them to `~/.openclaw/tools-config.json` for persistence

## 4. Subsequent Runs

The server will auto-start when you use `M-x emacs-openclaw-chat` (if not already running).

**Use from Emacs:**
```
C-c C-w s    ;; Open chat (auto-starts server)
C-c C-w r    ;; Quick send (from anywhere)
```

**Manual server control:**
```
M-x emacs-openclaw--start-server  ;; Start manually
M-x emacs-openclaw--stop-server   ;; Stop server
M-x emacs-openclaw-show-server-buffer  ;; View server logs
```

## Testing the Backend Directly

Once the server is running:

```bash
# List emails
curl http://127.0.0.1:3333/emails?limit=5 | jq

# Search
curl "http://127.0.0.1:3333/search-emails?query=from:andy.laurito@gmail.com" | jq

# OpenAPI docs
open http://127.0.0.1:3333/docs
```

## Troubleshooting

**"client_secret.json not found"**
→ See "Get OAuth Credentials" above

**"No module named 'fastapi'"**
```bash
cd server
pip install -r requirements.txt
```

**Emacs shows connection error**
- Check if server is running: `curl http://127.0.0.1:3333/docs`
- Verify URL in init.el: `(setq openclaw-base-url "http://127.0.0.1:3333")`
  (Note: NOT 18789, that's the OpenClaw gateway port)

**Token expired**
- Delete `server/token.json`
- Run `./start-server.sh` again

## What's Next

- [ ] Try the email examples
- [ ] Build a compose UI
- [ ] Add calendar integration
- [ ] Explore streaming responses

See `DEVELOPMENT.md` for architecture and adding features.
