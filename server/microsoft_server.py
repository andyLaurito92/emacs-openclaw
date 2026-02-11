"""
Microsoft 365 API routes for FastAPI.
Provides endpoints for email and calendar operations via Microsoft Graph.
"""

from fastapi import APIRouter, HTTPException
from typing import List, Optional
import logging
import os

from microsoft_tools import (
    microsoft_list_emails,
    microsoft_search_emails,
    microsoft_send_email,
    microsoft_delete_email,
    microsoft_create_calendar_event,
    microsoft_delete_calendar_event,
    microsoft_list_calendar_events,
)

router = APIRouter(prefix="/microsoft", tags=["microsoft"])
logger = logging.getLogger(__name__)


def _check_auth():
    """Check if Microsoft auth token exists."""
    if not os.path.exists("microsoft_token.json"):
        raise HTTPException(
            status_code=401,
            detail="Microsoft 365 not authenticated. Run: python3 microsoft_auth.py",
        )


# ==================== EMAIL ENDPOINTS ====================


@router.get("/emails")
def list_emails(limit: int = 10):
    """List recent emails from Outlook inbox."""
    try:
        _check_auth()
        emails = microsoft_list_emails(limit=limit)
        return {"emails": emails}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in list_emails: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search-emails")
def search_emails(query: str, limit: int = 10):
    """Search emails using Microsoft Graph query syntax."""
    try:
        _check_auth()
        emails = microsoft_search_emails(query=query, limit=limit)
        return {"emails": emails}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in search_emails: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/send-email")
def send_email(to: str, subject: str, body: str):
    """Send an email via Outlook."""
    try:
        _check_auth()
        result = microsoft_send_email(to=to, subject=subject, body=body)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_email: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/email/{message_id}")
def delete_email(message_id: str):
    """Delete (move to trash) an email by message ID."""
    try:
        _check_auth()
        result = microsoft_delete_email(message_id=message_id)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in delete_email: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== CALENDAR ENDPOINTS ====================


@router.get("/events")
def list_events(limit: int = 10):
    """List upcoming calendar events from Outlook."""
    try:
        _check_auth()
        events = microsoft_list_calendar_events(limit=limit)
        return {"events": events}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in list_events: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calendar-event")
def create_event(
    summary: str,
    start_iso: str,
    end_iso: str,
    description: Optional[str] = None,
    attendees: Optional[List[str]] = None,
):
    """Create a calendar event in Outlook."""
    try:
        _check_auth()
        result = microsoft_create_calendar_event(
            summary=summary,
            start_iso=start_iso,
            end_iso=end_iso,
            description=description,
            attendees=attendees,
        )
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in create_event: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/calendar-event/{event_id}")
def delete_event(event_id: str):
    """Delete a calendar event by ID."""
    try:
        _check_auth()
        result = microsoft_delete_calendar_event(event_id=event_id)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in delete_event: {e}")
        raise HTTPException(status_code=500, detail=str(e))
