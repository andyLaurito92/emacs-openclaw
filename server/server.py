from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import logging
import os

from tools import send_email, create_calendar_event, delete_calendar_event, search_emails, delete_email, list_emails, list_drive_files, search_drive_files, get_drive_file, read_drive_file, create_drive_file, create_drive_folder, update_drive_file, delete_drive_file, share_drive_file

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
    title="OpenClaw Google Tools",
    version="1.0.0",
)


# =========================
# Schemas
# =========================

class SendEmailRequest(BaseModel):
    to: EmailStr
    subject: str
    body: str


class CalendarEventRequest(BaseModel):
    summary: str
    start_iso: str
    end_iso: str
    description: Optional[str] = None
    timezone: str = "UTC"
    attendees: Optional[List[EmailStr]] = None


class DriveFileRequest(BaseModel):
    name: Optional[str] = None
    content: str
    parent_folder_id: Optional[str] = None
    mime_type: str = "text/plain"


class DriveFolderRequest(BaseModel):
    name: str
    parent_folder_id: Optional[str] = None


# =========================
# Endpoints
# =========================

@app.get("/health")
def health_check():
    """Health check endpoint to verify server is running."""
    return {
        "status": "ok",
        "service": "OpenClaw Google Tools",
        "version": "1.0.0"
    }


@app.get("/tools")
def list_tools():
    """List available tools and their descriptions."""
    return {
        "tools": [
            {
                "name": "send_email",
                "endpoint": "/send-email",
                "method": "POST",
                "description": "Send an email via Gmail",
                "parameters": {
                    "to": "string (email address)",
                    "subject": "string",
                    "body": "string"
                }
            },
            {
                "name": "search_emails",
                "endpoint": "/search-emails",
                "method": "GET",
                "description": "Search emails using Gmail query syntax",
                "parameters": {
                    "query": "string (e.g., 'from:user@example.com')"
                }
            },
            {
                "name": "list_emails",
                "endpoint": "/emails",
                "method": "GET",
                "description": "List recent emails",
                "parameters": {
                    "limit": "integer (default: 10)"
                }
            },
            {
                "name": "delete_email",
                "endpoint": "/email/{message_id}",
                "method": "DELETE",
                "description": "Delete (trash) an email by message ID",
                "parameters": {
                    "message_id": "string (email ID)"
                }
            },
            {
                "name": "create_calendar_event",
                "endpoint": "/calendar-event",
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
                "name": "delete_calendar_event",
                "endpoint": "/calendar-event/{event_id}",
                "method": "DELETE",
                "description": "Delete a Google Calendar event by ID",
                "parameters": {
                    "event_id": "string (calendar event ID)"
                }
            },
            {
                "name": "list_drive_files",
                "endpoint": "/drive/files",
                "method": "GET",
                "description": "List files in Google Drive",
                "parameters": {
                    "query": "string (optional filter, e.g., \"name contains 'document'\")",
                    "limit": "integer (default: 10)"
                }
            },
            {
                "name": "search_drive_files",
                "endpoint": "/drive/search",
                "method": "GET",
                "description": "Search files in Google Drive",
                "parameters": {
                    "query": "string (search term)",
                    "limit": "integer (default: 10)"
                }
            },
            {
                "name": "get_drive_file",
                "endpoint": "/drive/file/{file_id}",
                "method": "GET",
                "description": "Get file metadata from Google Drive",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            },
            {
                "name": "read_drive_file",
                "endpoint": "/drive/file/{file_id}/read",
                "method": "GET",
                "description": "Read file content from Google Drive (supports Docs, Sheets, text files)",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            },
            {
                "name": "create_drive_file",
                "endpoint": "/drive/file",
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
                "name": "create_drive_folder",
                "endpoint": "/drive/folder",
                "method": "POST",
                "description": "Create a folder in Google Drive",
                "parameters": {
                    "name": "string (folder name)",
                    "parent_folder_id": "string (optional)"
                }
            },
            {
                "name": "update_drive_file",
                "endpoint": "/drive/file/{file_id}",
                "method": "PUT",
                "description": "Update file content in Google Drive",
                "parameters": {
                    "file_id": "string (file ID)",
                    "content": "string (new content)"
                }
            },
            {
                "name": "delete_drive_file",
                "endpoint": "/drive/file/{file_id}",
                "method": "DELETE",
                "description": "Delete a file from Google Drive",
                "parameters": {
                    "file_id": "string (file ID)"
                }
            }
        ]
    }


@app.post("/send-email")
def send_email_endpoint(payload: SendEmailRequest):
    try:
        send_email(
            to=payload.to,
            subject=payload.subject,
            body=payload.body,
        )
        return {"status": "sent"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/search-emails")
def search_emails_endpoint(query: str):
    try:
        logger.info(f"Searching emails with query: {query}")
        messages = search_emails(query)
        logger.info(f"Found {len(messages)} emails")
        return {"messages": messages}
    except Exception as e:
        logger.error(f"Error searching emails: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/emails")
def list_emails_endpoint(limit: int = 10):
    try:
        logger.info(f"Fetching last {limit} emails")
        emails = list_emails(limit)
        logger.info(f"Retrieved {len(emails)} emails")
        return {"emails": emails}
    except Exception as e:
        logger.error(f"Error listing emails: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/email/{message_id}")
def delete_email_endpoint(message_id: str):
    try:
        logger.info(f"Attempting to delete email: {message_id}")
        delete_email(message_id)
        logger.info(f"Successfully deleted email: {message_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting email {message_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/calendar-event")
def calendar_event_endpoint(payload: CalendarEventRequest):
    try:
        event = create_calendar_event(
            summary=payload.summary,
            start_iso=payload.start_iso,
            end_iso=payload.end_iso,
            description=payload.description,
            timezone=payload.timezone,
            attendees=payload.attendees,
        )
        return {
            "status": "created",
            "event": event,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/calendar-event/{event_id}")
def delete_calendar_event_endpoint(event_id: str):
    try:
        delete_calendar_event(event_id)
        return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# Google Drive Endpoints
# =========================

@app.get("/drive/files")
def list_drive_files_endpoint(query: Optional[str] = None, limit: int = 10):
    """List files in Google Drive."""
    try:
        logger.info(f"Listing drive files with query: {query}, limit: {limit}")
        files = list_drive_files(query=query, max_results=limit)
        logger.info(f"Found {len(files)} files")
        return {"files": files}
    except Exception as e:
        logger.error(f"Error listing drive files: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/drive/search")
def search_drive_files_endpoint(query: str, limit: int = 10):
    """Search files in Google Drive."""
    try:
        logger.info(f"Searching drive files with query: {query}")
        files = search_drive_files(query=query, max_results=limit)
        logger.info(f"Found {len(files)} files")
        return {"files": files}
    except Exception as e:
        logger.error(f"Error searching drive files: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/drive/file/{file_id}")
def get_drive_file_endpoint(file_id: str):
    """Get file metadata from Google Drive."""
    try:
        logger.info(f"Getting file metadata: {file_id}")
        file = get_drive_file(file_id)
        logger.info(f"Retrieved file: {file.get('name')}")
        return {"file": file}
    except Exception as e:
        logger.error(f"Error getting drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/drive/file/{file_id}/read")
def read_drive_file_endpoint(file_id: str):
    """Read file content from Google Drive."""
    try:
        logger.info(f"Reading file content: {file_id}")
        content = read_drive_file(file_id)
        logger.info(f"Successfully read file: {file_id}")
        return {"content": content}
    except Exception as e:
        logger.error(f"Error reading drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/drive/file")
def create_drive_file_endpoint(payload: DriveFileRequest):
    """Create a file in Google Drive."""
    try:
        logger.info(f"Creating drive file: {payload.name}")
        file = create_drive_file(
            name=payload.name,
            content=payload.content,
            parent_folder_id=payload.parent_folder_id,
            mime_type=payload.mime_type,
        )
        logger.info(f"Created file: {file.get('name')}")
        return {"file": file}
    except Exception as e:
        logger.error(f"Error creating drive file: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/drive/folder")
def create_drive_folder_endpoint(payload: DriveFolderRequest):
    """Create a folder in Google Drive."""
    try:
        logger.info(f"Creating drive folder: {payload.name}")
        folder = create_drive_folder(
            name=payload.name,
            parent_folder_id=payload.parent_folder_id,
        )
        logger.info(f"Created folder: {folder.get('name')}")
        return {"folder": folder}
    except Exception as e:
        logger.error(f"Error creating drive folder: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/drive/file/{file_id}")
def update_drive_file_endpoint(file_id: str, payload: DriveFileRequest):
    """Update file content in Google Drive."""
    try:
        logger.info(f"Updating drive file: {file_id}")
        file = update_drive_file(file_id=file_id, content=payload.content)
        logger.info(f"Updated file: {file.get('name')}")
        return {"file": file}
    except Exception as e:
        logger.error(f"Error updating drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/drive/file/{file_id}")
def delete_drive_file_endpoint(file_id: str):
    """Delete a file from Google Drive."""
    try:
        logger.info(f"Deleting drive file: {file_id}")
        delete_drive_file(file_id)
        logger.info(f"Successfully deleted file: {file_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/drive/file/{file_id}/share")
def share_drive_file_endpoint(file_id: str, email: str, role: str = "reader"):
    """Share a Google Drive file with someone."""
    try:
        logger.info(f"Sharing drive file {file_id} with {email} as {role}")
        result = share_drive_file(file_id=file_id, email=email, role=role)
        logger.info(f"Successfully shared file with {email}")
        return {"status": "shared", "permission": result}
    except Exception as e:
        logger.error(f"Error sharing drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
