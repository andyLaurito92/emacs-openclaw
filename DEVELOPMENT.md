# DEVELOPMENT.md

## Project Structure

```
emacs-openclaw/
├── README.md                          # Main project overview
├── DEVELOPMENT.md                     # This file
├── .gitignore                         # Git ignore rules
├── .github/workflows/
│   └── lint.yml                       # CI: Python linting
├── server/                            # FastAPI backend
│   ├── server.py                      # Main FastAPI app
│   ├── tools.py                       # Gmail + Calendar API wrappers
│   ├── requirements.txt               # Python dependencies
│   └── README-SERVER.md               # Server-specific docs
└── examples/
    └── simple-chat.el                 # Usage examples
```

## Development Workflow

### 1. Starting the Server

```bash
cd server
python server.py
```

The server will:
- Open your browser for OAuth (first run only)
- Save token to `token.json`
- Start listening on `http://127.0.0.1:3333`

Logs are written to `logs.txt` and stdout.

### 2. Testing the API

Use `curl` to test endpoints:

```bash
# List emails
curl -s http://127.0.0.1:3333/emails?limit=5 | jq

# Search emails
curl -s "http://127.0.0.1:3333/search-emails?query=from:someone@example.com" | jq

# Delete an email (get ID from list first)
curl -s -X DELETE http://127.0.0.1:3333/email/19c32228879d1ecd
```

### 3. Emacs Development

The Emacs code currently lives in your `~/.emacs.d/init.el` (section 19).

**To test changes:**
1. Edit the code in init.el
2. Reload: `M-x eval-buffer`
3. Test: `M-x andy/openclaw-chat`

**When moving to standalone package:**
- Extract section 19 into `emacs-openclaw.el`
- Add customization variables (`defcustom`)
- Document all public functions
- Test with `use-package` and `straight.el`

## Adding Features

### New API Endpoint (Server Side)

1. Add function to `tools.py`:
```python
def new_feature(param1: str) -> dict:
    """Docstring."""
    creds = _load_creds()
    service = build("service", "v1", credentials=creds)
    # ... implement
    return result
```

2. Add endpoint to `server.py`:
```python
@app.post("/new-feature")
def new_feature_endpoint(payload: SomeRequest):
    try:
        result = new_feature(payload.param)
        return {"status": "success", "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

3. Test with curl, then integrate into Emacs.

### New Emacs UI

1. Add function to init.el:
```elisp
(defun andy/new-feature ()
  "Description."
  (interactive)
  (request
    (concat openclaw-base-url "/new-feature")
    :type "POST"
    :data (json-encode `((param . "value")))
    ;; ... handle response
    ))
```

2. Bind to key and test
3. Once stable, move to standalone package

## Testing

### Server Tests
```bash
cd server
pip install pytest
pytest
```

(Currently no tests; add as needed)

### Emacs Tests
Load examples and manually test:
```
M-x load-file examples/simple-chat.el
M-x example/ask-openclaw
```

## Committing

Keep commits clean and focused:
- One feature per commit
- Write descriptive messages
- Reference issues/tickets if applicable

Example:
```
git add server/tools.py
git commit -m "feat(server): Add delete_email function"
```

## Next Steps

- [ ] Move Emacs code to `emacs-openclaw.el` once stable
- [ ] Add email composition UI
- [ ] Add calendar event creation UI
- [x] Implement streaming responses (WebSocket-based)
- [ ] Unit tests for server
- [ ] MELPA publication workflow

---

Questions? Check the README.md or open an issue.
