# emacs-openclaw

Talk to OpenClaw directly from Emacs. A minor mode + FastAPI backend for seamless AI assistance in your editor.

## Features

- 💬 **Chat with OpenClaw** — Interactive chat buffer right in Emacs
- 📧 **Gmail Integration** — List, search, and delete emails (backend included)
- 📅 **Google Calendar** — Create and manage calendar events
- 🔌 **HTTP-based** — Separates Emacs UI from backend API
- 🚀 **Auto-start Server** — Server starts automatically when needed (optional)

## Quick Start

### 1. Server Setup

The server now handles OAuth intelligently and only prompts when needed:

```bash
cd server/
pip install -r requirements.txt
```

**First-time OAuth setup:**
1. Follow the OAuth setup instructions in [server/README-SERVER.md](server/README-SERVER.md) to get `client_secret.json`
2. Place `client_secret.json` in the `server/` directory
3. The server will automatically prompt for OAuth when it first starts (only once)

**Starting the server manually (optional):**
```bash
./start-server.sh
```

Or let Emacs start it automatically (see below).

### 2. Emacs Configuration

Add to your `init.el`:

```elisp
(use-package emacs-openclaw
  :straight (:host github :repo "andyLaurito92/emacs-openclaw")
  :bind (("C-c C-w s" . emacs-openclaw-chat)
         ("C-c C-w r" . emacs-openclaw-send-region-or-buffer))
  :config
  ;; Token and port are auto-detected from ~/.openclaw/openclaw.json
  ;; Override if needed:
  ;; (setq emacs-openclaw-token "your-token")
  ;; (setq emacs-openclaw-port 18789)
  
  ;; Server auto-start (enabled by default)
  ;; Set to nil to disable auto-start
  ;; (setq emacs-openclaw-auto-start-server nil)
  
  ;; Server port (default: 3333)
  ;; (setq emacs-openclaw-server-port 3333)
  
  ;; Evil mode keybindings (if you use Evil)
  (with-eval-after-load 'evil
    (evil-define-key 'insert emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line)
    (evil-define-key 'normal emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line)))
```

### 3. Usage

**Start a chat:**
```
C-c C-w s   ;; Open OpenClaw chat buffer (auto-starts server if needed)
```

**Send a message:**
```
Type your message and press RET
```

**Quick send from anywhere:**
```
C-c C-w r   ;; Send region (or whole buffer) to OpenClaw
```

**Check available tools:**
```
M-x emacs-openclaw-get-available-tools   ;; Lists Gmail/Calendar tools
```

**Server management:**
```
M-x emacs-openclaw--start-server         ;; Start server manually
M-x emacs-openclaw--stop-server          ;; Stop server
M-x emacs-openclaw-show-server-buffer    ;; View server logs
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Emacs Minor Mode                │
│   (HTTP client + chat UI)               │
│   • Auto-starts server if needed        │
│   • Discovers available tools           │
│   • Persists tool config                │
└────────────────┬────────────────────────┘
                 │
                 │ HTTP (localhost:3333)
                 │
┌────────────────▼────────────────────────┐
│      FastAPI Server                     │
│  (Gmail + Calendar OAuth wrapper)       │
│  • OAuth on first run only              │
│  • /health - Server status              │
│  • /tools - Tool discovery              │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┴──────────────┐
    │                           │
┌───▼────────┐         ┌───────▼──┐
│    Gmail   │         │ Calendar │
│    API     │         │   API    │
└────────────┘         └──────────┘
```

## Tool Discovery

The package includes a tool discovery mechanism that allows OpenClaw to know about available Gmail/Calendar tools:

1. **Server-side:** The `/tools` endpoint lists all available tools with their descriptions
2. **Client-side:** Use `M-x emacs-openclaw-get-available-tools` to fetch and display available tools
3. **Persistence:** Tool information is saved to `~/.openclaw/tools-config.json` for future reference

## Configuration

### Token & URL (in Emacs)

```elisp
(setq emacs-openclaw-token "your-token-here")
(setq emacs-openclaw-base-url "http://127.0.0.1:18789")
(setq emacs-openclaw-session-key "emacs-session")
(setq emacs-openclaw-server-port 3333)  ; Gmail/Calendar tools server port
(setq emacs-openclaw-auto-start-server t)  ; Auto-start server (default: t)
```

### Customizing Chat Appearance

You can customize the colors used in the chat buffer:

```elisp
;; Customize user input face (default: green, bold)
(custom-set-faces
 '(emacs-openclaw-user-face ((t :foreground "blue" :weight bold))))

;; Customize OpenClaw response face (default: cyan, normal)
(custom-set-faces
 '(emacs-openclaw-response-face ((t :foreground "magenta" :weight normal))))
```

### Customizing Chat Appearance

You can customize the colors used in the chat buffer:

```elisp
;; Customize user input face (default: green, bold)
(custom-set-faces
 '(emacs-openclaw-user-face ((t :foreground "blue" :weight bold))))

;; Customize OpenClaw response face (default: cyan, normal)
(custom-set-faces
 '(emacs-openclaw-response-face ((t :foreground "magenta" :weight normal))))
```

### Server Port

The Gmail/Calendar tools server runs on port 3333 by default. You can customize this in Emacs:

```elisp
(setq emacs-openclaw-server-port 3333)
```

Or change it in `start-server.sh`:
```bash
python3 -m uvicorn server:app --host 127.0.0.1 --port 3333
```

### OAuth Behavior

The server now intelligently handles OAuth:
- **First run:** Opens browser for OAuth consent, saves token to `server/token.json`
- **Subsequent runs:** Uses existing token, no browser interaction needed
- **Token refresh:** Automatically refreshes expired tokens

To re-authenticate, simply delete `server/token.json` and restart the server.

## License

MIT

## Contributing

POC phase — features and architecture may change rapidly.
