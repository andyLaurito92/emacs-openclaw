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
  :bind (("C-c C-w s" . emacs-openclaw-chat)
         ("C-c C-w r" . emacs-openclaw-send-region-or-buffer))
  :config
  ;; Token and port are auto-detected from ~/.openclaw/openclaw.json
  ;; Override if needed:
  ;; (setq emacs-openclaw-token "your-token")
  ;; (setq emacs-openclaw-port 18789)
  
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

Change server port in `server.py`:
```python
uvicorn.run(app, host="127.0.0.1", port=3333)
```

## License

MIT

## Contributing

POC phase — features and architecture may change rapidly.
