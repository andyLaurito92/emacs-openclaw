# emacs-openclaw — Claude Code Instructions

## Preferred Development Workflow

1. **Create a branch** named `feature/<feature-name>` (e.g. `feature/show-tool-activity`).
2. Make iterative, focused commits on the branch as work progresses.
3. **Verify CI locally before opening a PR.** Run the same checks the CI runs:
   ```bash
   # Paren check — catches unbalanced parens in any .el file you touched
   awk 'BEGIN{d=0}{for(i=1;i<=length($0);i++){c=substr($0,i,1);if(c=="(")d++;else if(c==")"){d--;if(d<0){print "Extra ) line "NR" col "i;d=0}}}}END{if(d!=0)print "Unmatched opens: "d}' <file>.el

   # Byte-compile (requires Emacs with deps installed)
   emacs -Q --batch -L . --eval "(package-initialize)" -f batch-byte-compile emacs-openclaw.el
   ```
   Alternatively, use the running Emacs server via the `/emacs/eval` endpoint:
   ```bash
   curl -s -X POST http://localhost:3333/emacs/eval \
     -H "Content-Type: application/json" \
     -d '{"code": "(with-temp-buffer (insert-file-contents \"path/to/file.el\") (condition-case err (progn (check-parens) \"ok\") (error (format \"%s\" err))))"}'
   ```
4. **Open a PR targeting `main`** and request GitHub Copilot as reviewer:
   ```bash
   gh pr create --base main ...
   ```
   Then add Copilot as reviewer via the GitHub web UI (PR page → Reviewers → search "Copilot"), or enable auto-review in *repo Settings → Code review → Copilot*.
   The `--reviewer copilot` CLI flag does not work reliably — use the web UI.
5. Do not push directly to `main`.

## Project Overview

An Emacs minor mode + FastAPI backend for chatting with the OpenClaw AI gateway from inside Emacs.

- **Emacs side**: `emacs-openclaw*.el` — WebSocket client, chat buffer, TTS, speech-to-text, buffer management API.
- **Python server** (`server/`): FastAPI app on port 3333 exposing Gmail, Calendar, Neo4j, and Emacs buffer tools to the OpenClaw gateway.
- **Gateway**: OpenClaw WebSocket server (port 18789) — not in this repo; users run it separately.

## Key Configuration

- `emacs-openclaw-python-executable` — must point to a Python with server deps installed (e.g. `server/venv/bin/python3`).
- `emacs-openclaw-server-port` — FastAPI tools server port (default 3333).
- Gateway token/port are auto-read from `~/.openclaw/openclaw.json`.

## Architecture Notes

```
Emacs (websocket client) ←→ OpenClaw Gateway (ws :18789) ←→ FastAPI server (http :3333)
```

The FastAPI server exposes `/emacs/*` endpoints (backed by `emacsclient`) so the gateway agent can read/write Emacs buffers as tools.
