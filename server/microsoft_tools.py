"""
Microsoft 365 / Outlook integration tools using Microsoft Graph API.
Handles email and calendar operations with delegated auth (user login).
"""

import requests
import json
import os
from datetime import datetime
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)

# Microsoft Graph API endpoint
GRAPH_API = "https://graph.microsoft.com/v1.0"

# Azure AD credentials
TENANT_ID = "75c134e8-fab3-4579-9137-be61dce6b5d3"
CLIENT_ID = "7735546e-16e6-45a1-be7f-4d1968d8d5bb"
CLIENT_SECRET_PATH = "/Users/andreslaurito/.ssh/azure-openclaw-integration.txt"

# Token storage
TOKEN_PATH = "microsoft_token.json"

# Token cache
_access_token = None
_token_expiry = None


def _get_client_secret():
    """Load client secret from file."""
    try:
        with open(CLIENT_SECRET_PATH, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        logger.error(f"Client secret not found at {CLIENT_SECRET_PATH}")
        raise


def _save_token(token_data):
    """Save token to file for later use."""
    with open(TOKEN_PATH, 'w') as f:
        json.dump(token_data, f)
    logger.info(f"Token saved to {TOKEN_PATH}")


def _load_token():
    """Load stored token from file."""
    if os.path.exists(TOKEN_PATH):
        try:
            with open(TOKEN_PATH, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Could not load token file: {e}")
    return None


def _refresh_access_token(refresh_token):
    """Use refresh token to get a new access token."""
    try:
        client_secret = _get_client_secret()
        
        token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
        
        payload = {
            "client_id": CLIENT_ID,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
            "scope": "Mail.ReadWrite Mail.Send Calendars.ReadWrite offline_access"
        }
        
        response = requests.post(token_url, data=payload)
        response.raise_for_status()
        
        data = response.json()
        logger.info("Successfully refreshed Microsoft Graph access token")
        return data
    
    except Exception as e:
        logger.error(f"Failed to refresh access token: {e}")
        raise


def _get_access_token():
    """Get a valid access token, refreshing if necessary."""
    global _access_token, _token_expiry
    
    # Return cached token if still valid (with 5-min buffer)
    if _access_token and _token_expiry:
        if datetime.now().timestamp() < (_token_expiry - 300):
            return _access_token
    
    # Try to load from file and refresh
    token_data = _load_token()
    if not token_data:
        raise Exception(
            "No token found. Please run: python3 microsoft_auth.py to authenticate"
        )
    
    # Refresh the token
    try:
        new_token_data = _refresh_access_token(token_data.get("refresh_token"))
        _save_token(new_token_data)
        
        _access_token = new_token_data["access_token"]
        _token_expiry = datetime.now().timestamp() + new_token_data["expires_in"]
        
        return _access_token
    except Exception as e:
        logger.error(f"Failed to get valid token: {e}")
        raise


def _graph_request(method, endpoint, **kwargs):
    """Make an authenticated request to Microsoft Graph API."""
    token = _get_access_token()
    
    url = f"{GRAPH_API}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    response = requests.request(method, url, headers=headers, **kwargs)
    
    if response.status_code in [401, 403]:
        # Token might be invalid, force refresh
        global _access_token, _token_expiry
        _access_token = None
        _token_expiry = None
        token = _get_access_token()
        headers["Authorization"] = f"Bearer {token}"
        response = requests.request(method, url, headers=headers, **kwargs)
    
    response.raise_for_status()
    return response


# ==================== EMAIL OPERATIONS ====================

def microsoft_list_emails(limit: int = 10) -> List[dict]:
    """List recent emails from Outlook."""
    try:
        response = _graph_request(
            "GET",
            "/me/mailFolders/inbox/messages",
            params={
                "$top": limit,
                "$select": "id,subject,from,receivedDateTime",
                "$orderby": "receivedDateTime desc"
            }
        )
        
        emails = []
        for msg in response.json().get("value", []):
            emails.append({
                "id": msg["id"],
                "subject": msg.get("subject", "(no subject)"),
                "from": msg.get("from", {}).get("emailAddress", {}).get("address", "unknown"),
                "date": msg.get("receivedDateTime", "")
            })
        
        return emails
    
    except Exception as e:
        logger.error(f"Error listing emails: {e}")
        raise


def microsoft_search_emails(query: str, limit: int = 10) -> List[dict]:
    """Search emails using Microsoft Graph query syntax."""
    try:
        # Microsoft uses $search parameter for full-text search
        response = _graph_request(
            "GET",
            "/me/mailFolders/inbox/messages",
            params={
                "$search": f'"{query}"',
                "$top": limit,
                "$select": "id,subject,from,receivedDateTime"
            }
        )
        
        emails = []
        for msg in response.json().get("value", []):
            emails.append({
                "id": msg["id"],
                "subject": msg.get("subject", "(no subject)"),
                "from": msg.get("from", {}).get("emailAddress", {}).get("address", "unknown"),
                "date": msg.get("receivedDateTime", "")
            })
        
        return emails
    
    except Exception as e:
        logger.error(f"Error searching emails: {e}")
        raise


def microsoft_send_email(to: str, subject: str, body: str) -> dict:
    """Send an email via Outlook."""
    try:
        payload = {
            "message": {
                "subject": subject,
                "body": {
                    "contentType": "text",
                    "content": body
                },
                "toRecipients": [
                    {
                        "emailAddress": {
                            "address": to
                        }
                    }
                ]
            }
        }
        
        response = _graph_request(
            "POST",
            "/me/sendMail",
            json=payload
        )
        
        logger.info(f"Email sent to {to}")
        return {"status": "success", "message": "Email sent"}
    
    except Exception as e:
        logger.error(f"Error sending email: {e}")
        raise


def microsoft_delete_email(message_id: str) -> dict:
    """Delete (move to trash) an email."""
    try:
        _graph_request(
            "DELETE",
            f"/me/messages/{message_id}"
        )
        
        logger.info(f"Email {message_id} deleted")
        return {"status": "success", "message": "Email deleted"}
    
    except Exception as e:
        logger.error(f"Error deleting email: {e}")
        raise


# ==================== CALENDAR OPERATIONS ====================

def microsoft_create_calendar_event(
    summary: str,
    start_iso: str,
    end_iso: str,
    description: Optional[str] = None,
    attendees: Optional[List[str]] = None
) -> dict:
    """Create a calendar event in Outlook."""
    try:
        payload = {
            "subject": summary,
            "body": {
                "contentType": "text",
                "content": description or ""
            },
            "start": {
                "dateTime": start_iso,
                "timeZone": "UTC"
            },
            "end": {
                "dateTime": end_iso,
                "timeZone": "UTC"
            },
            "isReminderOn": True,
            "reminderMinutesBeforeStart": 15
        }
        
        if attendees:
            payload["attendees"] = [
                {
                    "emailAddress": {
                        "address": email,
                        "name": email
                    },
                    "type": "required"
                }
                for email in attendees
            ]
        
        response = _graph_request(
            "POST",
            "/me/events",
            json=payload
        )
        
        event_id = response.json().get("id")
        logger.info(f"Calendar event created: {event_id}")
        return {
            "status": "success",
            "event_id": event_id,
            "message": "Calendar event created"
        }
    
    except Exception as e:
        logger.error(f"Error creating calendar event: {e}")
        raise


def microsoft_delete_calendar_event(event_id: str) -> dict:
    """Delete a calendar event."""
    try:
        _graph_request(
            "DELETE",
            f"/me/events/{event_id}"
        )
        
        logger.info(f"Calendar event {event_id} deleted")
        return {"status": "success", "message": "Calendar event deleted"}
    
    except Exception as e:
        logger.error(f"Error deleting calendar event: {e}")
        raise


def microsoft_list_calendar_events(limit: int = 10) -> List[dict]:
    """List upcoming calendar events."""
    try:
        response = _graph_request(
            "GET",
            "/me/events",
            params={
                "$top": limit,
                "$select": "id,subject,start,end",
                "$orderby": "start/dateTime asc"
            }
        )
        
        events = []
        for event in response.json().get("value", []):
            events.append({
                "id": event["id"],
                "subject": event.get("subject", "(no subject)"),
                "start": event.get("start", {}).get("dateTime", ""),
                "end": event.get("end", {}).get("dateTime", "")
            })
        
        return events
    
    except Exception as e:
        logger.error(f"Error listing calendar events: {e}")
        raise
