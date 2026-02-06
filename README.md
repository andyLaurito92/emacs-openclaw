# emacs-openclaw

Talk to OpenClaw directly from Emacs. A minor mode + FastAPI backend for seamless AI assistance in your editor.

## Features

- 💬 **Chat with OpenClaw** — Interactive chat buffer right in Emacs
- 📧 **Gmail Integration** — List, search, and delete emails (backend included)
- 📅 **Google Calendar** — Create and manage calendar events
- 🔌 **HTTP-based** — Separates Emacs UI from backend API

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
  :config
  (setq emacs-openclaw-token "your-openclaw-token-here")
  (setq emacs-openclaw-base-url "http://127.0.0.1:18789"))
```

Or manually load the package:

```elisp
(add-to-list 'load-path "~/repos/emacs-openclaw")
(require 'emacs-openclaw)
(setq emacs-openclaw-token "your-openclaw-token-here")
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
│   (HTTP client + chat UI)               │
└────────────────┬────────────────────────┘
                 │
                 │ HTTP (localhost:3333)
                 │
┌────────────────▼────────────────────────┐
│      FastAPI Server                     │
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

### Token & URL (in Emacs)

```elisp
(setq openclaw-token "your-token-here")
(setq openclaw-base-url "http://127.0.0.1:18789")
(setq openclaw-session-key "emacs-session")
```

### Server Port

Change server port in `server.py`:
```python
uvicorn.run(app, host="127.0.0.1", port=3333)
```

## License

MIT

## Contributing

POC phase — features and architecture may change rapidly.
