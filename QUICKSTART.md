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

### First Run (Authenticate)

```bash
cd ~/repos/emacs-openclaw
./start-server.sh
```

This will:
- Open your browser for OAuth consent
- Save token to `server/token.json`
- Start server on `http://127.0.0.1:3333`

Leave it running.

## 2. Test in Emacs

In a fresh Emacs session:

```elisp
M-x andy/openclaw-chat
```

You should see a `*OpenClaw-Chat*` buffer. Type a message and press RET.

## 3. Subsequent Runs

**Start server:**
```bash
cd ~/repos/emacs-openclaw
./start-server.sh
```

**Use from Emacs:**
```
C-c C-w s    ;; Open chat
C-c C-w r    ;; Quick send (from anywhere)
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
- [x] Explore streaming responses (WebSocket support added!)

See `DEVELOPMENT.md` for architecture and adding features.

## WebSocket vs HTTP

By default, emacs-openclaw now uses WebSocket for real-time streaming responses. You can configure this:

```elisp
;; Use WebSocket (default)
(setq emacs-openclaw-use-websocket t)

;; Or use HTTP
(setq emacs-openclaw-use-websocket nil)
```
