# emacs-openclaw

## important note

Regarding whisper, for now we need to run emacs like this from terminal

```
/Applications/Emacs.app/Contents/MacOS/Emacs &
```
so mic permissions are inherited from iterm. TODO: Fix the above so we don't ahve to do it :)

### How to test it from emacs

Run in vterm -> sox -d test.wav and later open test.wav -> If you don't listen anything, emacs doesn't have mic permissions yet :)

Talk to OpenClaw directly from Emacs. A minor mode + FastAPI backend for seamless AI assistance in your editor.

## Features

- 💬 **Chat with OpenClaw** — Interactive chat buffer right in Emacs with streaming responses
- 📧 **Gmail Integration** — List, search, and delete emails (backend included)
- 📅 **Google Calendar** — Create and manage calendar events
- 📋 **Buffer Management API** — OpenClaw can access and manipulate Emacs buffers in real-time via emacsclient
- 🎤 **Speech-to-Text** — Optional audio transcription via OpenAI Whisper CLI (disabled by default)
- 🔌 **WebSocket-based** — Real-time streaming chat via OpenClaw Gateway WebSocket protocol
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
M-x emacs-openclaw-disconnect            ;; Disconnect WebSocket (auto-reconnects on next message)
```

## Buffer Management API

OpenClaw can access and manipulate Emacs buffers in real-time through the `/emacs` endpoints. This allows OpenClaw to:
- List all visible buffers
- Create new buffers
- Read buffer contents
- Modify buffer contents
- Delete buffers

**Available Endpoints:**
```
GET    /emacs/buffers                      # List all visible buffer names
POST   /emacs/buffer                       # Create a new buffer
GET    /emacs/buffer/{name}/content        # Get buffer content
PUT    /emacs/buffer/{name}/content        # Set buffer content
DELETE /emacs/buffer/{name}                # Delete a buffer
```

**Requirements:**
- Emacs must be running in server mode (run `M-x server-start` or add `(server-start)` to your init.el)
- `emacsclient` must be available in your PATH

**Example Usage (via HTTP):**
```bash
# List all buffers
curl http://localhost:3333/emacs/buffers

# Get content of a buffer
curl http://localhost:3333/emacs/buffer/init.el/content

# Create a new buffer
curl -X POST http://localhost:3333/emacs/buffer -H "Content-Type: application/json" -d '{"name": "my-notes"}'

# Set buffer content
curl -X PUT http://localhost:3333/emacs/buffer/my-notes/content -H "Content-Type: application/json" -d '{"content": "Hello from OpenClaw!"}'

# Delete a buffer
curl -X DELETE http://localhost:3333/emacs/buffer/my-notes
```

These endpoints are automatically discovered by OpenClaw through the `/tools` endpoint and can be used by the AI agent to help with buffer-specific tasks.

## WebSocket Communication

The package now uses WebSocket protocol for real-time streaming chat with the OpenClaw Gateway:

- **Protocol:** JSON-based request/response over WebSocket
- **Default Port:** 18789 (configurable via `~/.openclaw/openclaw.json`)
- **Streaming:** Responses stream in real-time via `event:chat.delta` events
- **Authentication:** Token-based (auto-detected from `~/.openclaw/openclaw.json`)
- **Auto-reconnect:** Connection is established automatically when sending messages

The WebSocket connection provides a flowing conversation experience where you see the AI response appear character-by-character as it's being generated, instead of waiting for the complete response.

## Architecture

```
┌─────────────────────────────────────────┐
│         Emacs Minor Mode                │
│   (WebSocket client + chat UI)          │
│   • Streams responses in real-time      │
│   • Auto-reconnects if needed           │
│   • Discovers available tools           │
│   • Persists tool config                │
└────────────────┬────────────────────────┘
                 │
                 │ WebSocket (localhost:18789)
                 │ OpenClaw Gateway Protocol
                 │
┌────────────────▼────────────────────────┐
│      OpenClaw Gateway                   │
│  (WebSocket server + orchestrator)      │
│  • Handles chat.completions             │
│  • Streams via event:chat.delta         │
│  • Manages agent connections            │
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

### Thinking Indicator

While the agent is processing your message, a dimmed `Thinking…` line is shown
in the chat buffer and automatically removed when the first response text
arrives.  This is enabled by default; set it to `nil` to disable it:

```elisp
;; Disable the "Thinking…" indicator (default: t)
(setq emacs-openclaw-show-thinking-indicator nil)
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

You can also customize the welcome message and instructions:

```elisp
;; Customize welcome message (default: "Welcome to OpenClaw Chat!")
(setq emacs-openclaw-welcome-message "Hello! Ready to chat with OpenClaw?")

;; Customize instructions (default: "Type your message below and press RET to send.")
(setq emacs-openclaw-instructions "Enter your question and hit RET.")

;; Customize message separator
(setq emacs-openclaw-message-separator "────────────────────────────────")
```

### Speech-to-Text (Optional)

Enable optional audio transcription via the OpenAI Whisper CLI:

```elisp
;; Enable speech-to-text (requires Whisper CLI and ffmpeg)
(setq emacs-openclaw-allow-speech-to-text t)

;; Customize transcription keybinding (default: "C-c C-s")
(setq emacs-openclaw-whisper-keybinding "C-c C-s")

;; Customize Whisper model (default: "base")
;; Options: tiny, base, small, medium, large
(setq emacs-openclaw-whisper-model "base")

;; Optional: Specify language (default: auto-detect)
;; (setq emacs-openclaw-whisper-language "en")
```

For setup instructions, see [SPEECH_TO_TEXT.md](SPEECH_TO_TEXT.md).

**Note:** Speech-to-text is disabled by default and has zero overhead when not used.

### Text-to-Speech (Optional)

Enable audio playback of OpenClaw responses using your system's default text-to-speech engine:

```elisp
;; Enable text-to-speech (uses `say` on macOS, `espeak` on Linux)
(setq emacs-openclaw-tts-enabled t)

;; Or toggle TTS on/off interactively
;; M-x emacs-openclaw-tts-toggle

;; Customize TTS voice (macOS)
(setq emacs-openclaw-tts-voice "Samantha")  ; Default voice
;; Run `say -v ?` in terminal to see available voices

;; Customize speech rate (words per minute)
(setq emacs-openclaw-tts-rate 150)  ; Default: 150

;; For Linux, set the TTS command to espeak
(setq emacs-openclaw-tts-command "espeak")
(setq emacs-openclaw-tts-voice "english")  ; espeak voice name
```

**Available commands:**
- `M-x emacs-openclaw-tts-toggle` — Toggle TTS on/off
- `M-x emacs-openclaw-tts-list-voices` — List available voices (macOS only)

**Note:** Text-to-speech is disabled by default. No additional dependencies are required on macOS (uses built-in `say` command). On Linux, install `espeak` via your package manager.

### Python Executable

The server is launched using the Python executable configured via `emacs-openclaw-python-executable` (defaults to `"python3"`). You must point this to a Python that has the server dependencies installed (`uvicorn`, `fastapi`, etc.):

```elisp
;; If you use the project's virtualenv (recommended):
(setq emacs-openclaw-python-executable "/path/to/emacs-openclaw/server/venv/bin/python3")

;; If you use a conda environment:
(setq emacs-openclaw-python-executable "/opt/homebrew/anaconda3/envs/myenv/bin/python3")
```

To set up the virtualenv from scratch:
```bash
cd server/
python3 -m venv venv
venv/bin/pip install -r requirements.txt
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

## Release Process

This project uses automated CI/CD for releases with semantic versioning. See [RELEASE.md](RELEASE.md) for detailed documentation.

**Quick release:**
```bash
# Update version
echo "0.2.0" > VERSION
git add VERSION
git commit -m "chore: bump version to 0.2.0"
git push origin main
```

The CI/CD pipeline will automatically:
- Update package version in `emacs-openclaw.el`
- Generate changelog from commits
- Create git tag and GitHub release

For more options, see the [Release Documentation](RELEASE.md).

## Contributing

POC phase — features and architecture may change rapidly.

Please use conventional commit messages for automatic version bumping:
- `feat:` for new features (minor version bump)
- `fix:` for bug fixes (patch version bump)
- `feat!:` or `BREAKING CHANGE:` for breaking changes (major version bump)
