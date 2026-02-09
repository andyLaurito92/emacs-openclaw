# OpenClaw Tools Server

FastAPI server providing OAuth-authenticated access to Gmail, Google Calendar, and Microsoft 365 APIs.

## Quick Start

```bash
cd server
source venv/bin/activate  # or create one: python3 -m venv venv
pip install -r requirements.txt
python server.py
```

Server runs on `http://127.0.0.1:3333`

## Google Tools (✅ Production Ready)

Gmail and Google Calendar integration with automatic token refresh.

### Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project and enable Gmail + Calendar APIs
3. Create an "OAuth 2.0 Client ID" (Desktop application)
4. Download credentials as `client_secret.json` and place in `server/` directory
5. First run will open browser for OAuth consent and save `token.json`

### Endpoints

**Email:**
- `GET /google/emails?limit=10` — List recent emails
- `GET /google/search-emails?query=<query>` — Search emails
- `POST /google/send-email` — Send email
- `DELETE /google/email/{message_id}` — Delete/trash email

**Calendar:**
- `POST /google/calendar-event` — Create event
- `DELETE /google/calendar-event/{event_id}` — Delete event

**Drive:**
- `GET /google/drive/files?limit=10` — List files
- `GET /google/drive/search?query=<query>` — Search Drive
- `GET /google/drive/file/{file_id}/read` — Read file content
- `POST /google/drive/file` — Create file
- `PUT /google/drive/file/{file_id}` — Update file
- `DELETE /google/drive/file/{file_id}` — Delete file

---

## Microsoft 365 Tools (⚠️ Requires Exchange Online)

Outlook email and calendar integration via Microsoft Graph API.

### ⚠️ Important Limitation

**Microsoft 365 requires a proper work/school account with Exchange Online.**

❌ **Does NOT work with:**
- Personal Hotmail/Outlook.com accounts
- External identities (guest accounts)
- Accounts without Exchange Online mailbox

✅ **Works with:**
- Microsoft 365 Business/Enterprise accounts
- Accounts with full Exchange Online mailbox

**Error:** If you see `MailboxNotEnabledForRESTAPI`, your account doesn't have an Exchange Online mailbox. Contact your IT admin or use a different account.

### Setup (if you have Exchange Online)

1. Register a redirect URI in Azure AD:
   - Go to [Azure Portal](https://portal.azure.com)
   - App registrations → find the OpenClaw app
   - Authentication → Add redirect URI: `http://localhost:8080/callback`
   - Save

2. Run the auth script:
   ```bash
   python microsoft_auth.py
   ```
   This opens your browser for OAuth consent and saves `microsoft_token.json`

3. Server will automatically use the refresh token for subsequent calls

### Endpoints

**Email:**
- `GET /microsoft/emails?limit=10` — List recent emails
- `GET /microsoft/search-emails?query=<query>` — Search emails
- `POST /microsoft/send-email` — Send email
- `DELETE /microsoft/email/{message_id}` — Delete/trash email

**Calendar:**
- `GET /microsoft/events?limit=10` — List upcoming events
- `POST /microsoft/calendar-event` — Create event
- `DELETE /microsoft/calendar-event/{event_id}` — Delete event

---

## Development

- Auto-refreshing credentials
- Detailed logging in `logs.txt` and console
- Token files: `token.json` (Google), `microsoft_token.json` (Microsoft)

Stop: `Ctrl+C`
