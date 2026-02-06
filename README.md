# emacs-openclaw

Talk to OpenClaw directly from Emacs. A minor mode + FastAPI backend for seamless AI assistance in your editor.

## Features

- 💬 **Chat with OpenClaw** — Interactive chat buffer right in Emacs
- 🌊 **WebSocket Streaming** — Real-time streaming responses for flowing conversations
- 📧 **Gmail Integration** — List, search, and delete emails (backend included)
- 📅 **Google Calendar** — Create and manage calendar events
- 🔌 **Flexible Communication** — WebSocket (default) or HTTP fallback

## Quick Start

### 1. Server Setup

```bash
cd server/
pip install -r requirements.txt
./start-server.sh
```

See [server/README-SERVER.md](server/README-SERVER.md) for detailed OAuth setup instructions.

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
  
  ;; WebSocket is enabled by default for streaming responses
  ;; Set to nil to use HTTP instead:
  ;; (setq emacs-openclaw-use-websocket nil)
  
  ;; Evil mode keybindings (if you use Evil)
  (with-eval-after-load 'evil
    (evil-define-key 'insert emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line)
    (evil-define-key 'normal emacs-openclaw-mode-map (kbd "RET") #'emacs-openclaw-send-line)))
```

### 3. Usage

**Start a chat:**
```
C-c C-w s   ;; Open OpenClaw chat buffer
```

**Send a message:**
```
Type your message and press RET
```

**Quick send from anywhere:**
```
C-c C-w r   ;; Send region (or whole buffer) to OpenClaw
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Emacs Minor Mode                │
│  (WebSocket/HTTP client + chat UI)      │
└────────────────┬────────────────────────┘
                 │
                 │ WebSocket (streaming) or HTTP
                 │ (localhost:18789)
                 │
┌────────────────▼────────────────────────┐
│      OpenClaw Gateway                   │
│   (AI model + conversation state)       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      FastAPI Server (Optional)          │
│  (Gmail + Calendar OAuth wrapper)       │
└────────────────┬────────────────────────┘
                 │
    ┌────────────┴──────────────┐
    │                           │
┌───▼────────┐         ┌───────▼──┐
│    Gmail   │         │ Calendar │
│    API     │         │   API    │
└────────────┘         └──────────┘
```

## Configuration

### Communication Mode

By default, emacs-openclaw uses WebSocket for streaming responses. You can control this:

```elisp
;; Use WebSocket (default - streaming responses)
(setq emacs-openclaw-use-websocket t)

;; Or use HTTP (non-streaming, fallback mode)
(setq emacs-openclaw-use-websocket nil)
```

### Token & URL (in Emacs)

```elisp
(setq emacs-openclaw-token "your-token-here")
(setq emacs-openclaw-port 18789)
(setq emacs-openclaw-session-key "emacs-session")
```

Configuration is auto-detected from `~/.openclaw/openclaw.json` if available.

### Server Port

Change server port in `server.py`:
```python
uvicorn.run(app, host="127.0.0.1", port=3333)
```

## License

MIT

## Contributing

POC phase — features and architecture may change rapidly.
