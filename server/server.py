from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import logging
import os

from tools import send_email, create_calendar_event, delete_calendar_event, search_emails, delete_email, list_emails

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
]

# Only run OAuth flow if token doesn't exist
if not os.path.exists("token.json"):
    logger.info("token.json not found, starting OAuth flow...")
    if not os.path.exists("client_secret.json"):
        logger.error("client_secret.json not found! Cannot authenticate.")
        raise FileNotFoundError(
            "client_secret.json is required for OAuth authentication. "
            "Please follow the setup instructions in README-SERVER.md"
        )
    
    flow = InstalledAppFlow.from_client_secrets_file(
        "client_secret.json", SCOPES
    )
    creds = flow.run_local_server(port=8080, open_browser=True)
    
    with open("token.json", "w") as f:
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
