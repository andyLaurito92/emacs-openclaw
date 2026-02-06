import base64
from email.message import EmailMessage
from typing import Optional, List


from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

# ---- Config ----
TOKEN_FILE = "token.json"
GMAIL_API = ("gmail", "v1")
CALENDAR_API = ("calendar", "v3")


def _load_creds() -> Credentials:
    from google.auth.transport.requests import Request
    
    creds = Credentials.from_authorized_user_file(TOKEN_FILE)
    
    # Force refresh to get fresh token with latest scopes
    if creds.refresh_token:
        creds.refresh(Request())
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Refreshed credentials with scopes: {creds.scopes}")
    
    return creds


# =========================
# Gmail
# =========================

def send_email(
    to: str,
    subject: str,
    body: str,
) -> None:
    """
    Send an email using the authenticated Gmail account.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    msg = EmailMessage()
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)

    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode("utf-8")

    service.users().messages().send(
        userId="me",
        body={"raw": raw}
    ).execute()


def search_emails(query: str) -> list:
    """
    Search emails by query string.
    Returns a list of message IDs.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = service.users().messages().list(
        userId="me",
        q=query,
    ).execute()

    return results.get("messages", [])


def get_email(message_id: str) -> dict:
    """
    Get full email details by message ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    msg = service.users().messages().get(
        userId="me",
        id=message_id,
        format="full",
    ).execute()

    headers = msg["payload"]["headers"]
    subject = next((h["value"] for h in headers if h["name"] == "Subject"), "")
    from_addr = next((h["value"] for h in headers if h["name"] == "From"), "")
    date = next((h["value"] for h in headers if h["name"] == "Date"), "")

    return {
        "id": message_id,
        "subject": subject,
        "from": from_addr,
        "date": date,
    }


def list_emails(max_results: int = 10) -> list:
    """
    Get the last N emails (unread and read).
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = service.users().messages().list(
        userId="me",
        maxResults=max_results,
    ).execute()

    messages = results.get("messages", [])
    return [get_email(msg["id"]) for msg in messages]


def delete_email(message_id: str) -> None:
    """
    Delete an email by message ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().messages().trash(
        userId="me",
        id=message_id,
    ).execute()


# =========================
# Google Calendar
# =========================

def create_calendar_event(
    summary: str,
    start_iso: str,
    end_iso: str,
    description: Optional[str] = None,
    timezone: str = "UTC",
    attendees: Optional[List[str]] = None,
) -> dict:
    """
    Create a calendar event on the primary calendar.

    start_iso / end_iso must be ISO-8601 strings, e.g:
    2026-02-05T10:00:00
    """
    creds = _load_creds()
    service = build(*CALENDAR_API, credentials=creds)

    event = {
        "summary": summary,
        "description": description,
        "start": {
            "dateTime": start_iso,
            "timeZone": timezone,
        },
        "end": {
            "dateTime": end_iso,
            "timeZone": timezone,
        },
    }

    if attendees:
        event["attendees"] = [{"email": e} for e in attendees]

    created = service.events().insert(
        calendarId="primary",
        body=event,
        sendUpdates="all",   # ← THIS sends the invites
    ).execute()

    return {
        "id": created.get("id"),
        "htmlLink": created.get("htmlLink"),
    }


def delete_calendar_event(event_id: str) -> None:
    """
    Delete a calendar event by ID.
    """
    creds = _load_creds()
    service = build(*CALENDAR_API, credentials=creds)

    service.events().delete(
        calendarId="primary",
        eventId=event_id,
        sendUpdates="all",
    ).execute()
