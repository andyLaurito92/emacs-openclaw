# OpenClaw Google Tools Server

FastAPI server providing OAuth-authenticated access to Gmail and Google Calendar APIs.

## Setup

1. **Google OAuth Credentials**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project
   - Enable Gmail and Calendar APIs
   - Create an "OAuth 2.0 Client ID" (Desktop application)
   - Download credentials as `client_secret.json` and place in this directory

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **First Run (Authentication)**
   ```bash
   python server.py
   ```
   This will:
   - Open your browser for OAuth consent
   - Save credentials to `token.json`
   - Start the FastAPI server on `http://127.0.0.1:3333`

4. **Subsequent Runs**
   ```bash
   python server.py
   ```
   The server will automatically use the saved `token.json`

## API Endpoints

### Email

- `GET /emails?limit=10` — List recent emails
- `GET /search-emails?query=<query>` — Search emails (e.g., `from:user@example.com`)
- `POST /send-email` — Send an email
- `DELETE /email/{message_id}` — Delete/trash an email

### Calendar

- `POST /calendar-event` — Create a calendar event
- `DELETE /calendar-event/{event_id}` — Delete a calendar event

## Development

The server auto-refreshes credentials and includes detailed logging in `logs.txt` and console output.

To stop the server: `Ctrl+C`
