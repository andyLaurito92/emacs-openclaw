from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

from fastapi import FastAPI
import logging
import os

from google_server import router as google_router
from microsoft_server import router as microsoft_router

# Setup logging to file and console
log_file = "logs.txt"
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)
logger.info("Server starting up...")

SCOPES = [
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/drive",
]

# Get client_secret path from environment or use default
CLIENT_SECRET_PATH = os.getenv("OPENCLAW_CLIENT_SECRET", "client_secret.json")
TOKEN_PATH = "token.json"

# Only run OAuth flow if token doesn't exist
if not os.path.exists(TOKEN_PATH):
    logger.info("token.json not found, starting OAuth flow...")
    if not os.path.exists(CLIENT_SECRET_PATH):
        logger.error(f"client_secret.json not found at {CLIENT_SECRET_PATH}! Cannot authenticate.")
        raise FileNotFoundError(
            f"client_secret.json is required for OAuth authentication. "
            f"Expected at: {CLIENT_SECRET_PATH} "
            f"Please follow the setup instructions in README-SERVER.md"
        )
    
    flow = InstalledAppFlow.from_client_secrets_file(
        CLIENT_SECRET_PATH, SCOPES
    )
    creds = flow.run_local_server(port=8080, open_browser=True)
    
    with open(TOKEN_PATH, "w") as f:
        f.write(creds.to_json())
    
    logger.info("OAuth complete, token saved to token.json")
else:
    logger.info("Found existing token.json, skipping OAuth flow")


app = FastAPI(
    title="OpenClaw Tools",
    version="1.0.0",
)


# =========================
# Mount Routers
# =========================

app.include_router(google_router)
app.include_router(microsoft_router)


# =========================
# Meta Endpoints
# =========================

@app.get("/health")
def health_check():
    """Health check endpoint to verify server is running."""
    return {
        "status": "ok",
        "service": "OpenClaw Tools Server",
        "version": "1.0.0"
    }


@app.get("/tools")
def list_tools():
    """List available tools and their descriptions."""
    return {
        "providers": ["google", "microsoft"],
        "tools": [
            {
                "provider": "google",
                "name": "send_email",
                "endpoint": "/google/send-email",
                "method": "POST",
                "description": "Send an email via Gmail",
                "parameters": {
                    "to": "string (email address)",
                    "subject": "string",
                    "body": "string"
                }
            },
            {
                "provider": "google",
                "name": "search_emails",
                "endpoint": "/google/search-emails",
                "method": "GET",
                "description": "Search emails using Gmail query syntax",
                "parameters": {
                    "query": "string (e.g., 'from:user@example.com')"
                }
            },
            {
                "provider": "google",
                "name": "list_emails",
                "endpoint": "/google/emails",
                "method": "GET",
                "description": "List recent emails",
                "parameters": {
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "google",
                "name": "delete_email",
                "endpoint": "/google/email/{message_id}",
                "method": "DELETE",
                "description": "Delete (trash) an email by message ID",
                "parameters": {
                    "message_id": "string (email ID)"
                }
            },
            {
                "provider": "google",
                "name": "create_calendar_event",
                "endpoint": "/google/calendar-event",
                "method": "POST",
                "description": "Create a Google Calendar event",
                "parameters": {
                    "summary": "string",
                    "start_iso": "string (ISO-8601 datetime)",
                    "end_iso": "string (ISO-8601 datetime)",
                    "description": "string (optional)",
                    "timezone": "string (default: UTC)",
                    "attendees": "array of email addresses (optional)"
                }
            },
            {
                "provider": "google",
                "name": "delete_calendar_event",
                "endpoint": "/google/calendar-event/{event_id}",
                "method": "DELETE",
                "description": "Delete a Google Calendar event by ID",
                "parameters": {
                    "event_id": "string (calendar event ID)"
                }
            },
            {
                "provider": "google",
                "name": "list_drive_files",
                "endpoint": "/google/drive/files",
                "method": "GET",
                "description": "List files in Google Drive",
                "parameters": {
                    "query": "string (optional filter, e.g., \"name contains 'document'\")",
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "google",
                "name": "search_drive_files",
                "endpoint": "/google/drive/search",
                "method": "GET",
                "description": "Search files in Google Drive",
                "parameters": {
                    "query": "string (search term)",
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "google",
                "name": "get_drive_file",
                "endpoint": "/google/drive/file/{file_id}",
                "method": "GET",
                "description": "Get file metadata from Google Drive",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            },
            {
                "provider": "google",
                "name": "read_drive_file",
                "endpoint": "/google/drive/file/{file_id}/read",
                "method": "GET",
                "description": "Read file content from Google Drive (supports Docs, Sheets, text files)",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            },
            {
                "provider": "google",
                "name": "create_drive_file",
                "endpoint": "/google/drive/file",
                "method": "POST",
                "description": "Create a file in Google Drive",
                "parameters": {
                    "name": "string (file name)",
                    "content": "string (file content)",
                    "parent_folder_id": "string (optional)",
                    "mime_type": "string (default: 'text/plain')"
                }
            },
            {
                "provider": "google",
                "name": "create_drive_folder",
                "endpoint": "/google/drive/folder",
                "method": "POST",
                "description": "Create a folder in Google Drive",
                "parameters": {
                    "name": "string (folder name)",
                    "parent_folder_id": "string (optional)"
                }
            },
            {
                "provider": "google",
                "name": "update_drive_file",
                "endpoint": "/google/drive/file/{file_id}",
                "method": "PUT",
                "description": "Update file content in Google Drive",
                "parameters": {
                    "file_id": "string (file ID)",
                    "content": "string (new content)"
                }
            },
            {
                "provider": "google",
                "name": "delete_drive_file",
                "endpoint": "/google/drive/file/{file_id}",
                "method": "DELETE",
                "description": "Delete a file from Google Drive",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            },
            # MICROSOFT 365 TOOLS
            {
                "provider": "microsoft",
                "name": "send_email",
                "endpoint": "/microsoft/send-email",
                "method": "POST",
                "description": "Send an email via Outlook",
                "parameters": {
                    "to": "string (email address)",
                    "subject": "string",
                    "body": "string"
                }
            },
            {
                "provider": "microsoft",
                "name": "search_emails",
                "endpoint": "/microsoft/search-emails",
                "method": "GET",
                "description": "Search emails using Microsoft Graph query syntax",
                "parameters": {
                    "query": "string (search term)",
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "microsoft",
                "name": "list_emails",
                "endpoint": "/microsoft/emails",
                "method": "GET",
                "description": "List recent emails from Outlook inbox",
                "parameters": {
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "microsoft",
                "name": "delete_email",
                "endpoint": "/microsoft/email/{message_id}",
                "method": "DELETE",
                "description": "Delete (move to trash) an email by message ID",
                "parameters": {
                    "message_id": "string (email ID)"
                }
            },
            {
                "provider": "microsoft",
                "name": "list_events",
                "endpoint": "/microsoft/events",
                "method": "GET",
                "description": "List upcoming calendar events from Outlook",
                "parameters": {
                    "limit": "integer (default: 10)"
                }
            },
            {
                "provider": "microsoft",
                "name": "create_calendar_event",
                "endpoint": "/microsoft/calendar-event",
                "method": "POST",
                "description": "Create a calendar event in Outlook",
                "parameters": {
                    "summary": "string",
                    "start_iso": "string (ISO-8601 datetime)",
                    "end_iso": "string (ISO-8601 datetime)",
                    "description": "string (optional)",
                    "attendees": "array of email addresses (optional)"
                }
            },
            {
                "provider": "microsoft",
                "name": "delete_calendar_event",
                "endpoint": "/microsoft/calendar-event/{event_id}",
                "method": "DELETE",
                "description": "Delete a calendar event by ID",
                "parameters": {
                    "event_id": "string (calendar event ID)"
                }
            }
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=3333)
