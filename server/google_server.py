from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional, List
import logging

from google_tools import (
    google_send_email,
    google_create_calendar_event,
    google_delete_calendar_event,
    google_search_emails,
    google_delete_email,
    google_list_emails,
    google_list_drive_files,
    google_search_drive_files,
    google_get_drive_file,
    google_read_drive_file,
    google_create_drive_file,
    google_create_drive_folder,
    google_update_drive_file,
    google_delete_drive_file,
    google_share_drive_file,
)

logger = logging.getLogger(__name__)

# Create router with /google prefix
router = APIRouter(prefix="/google", tags=["google"])


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

@router.post("/send-email")
def send_email_endpoint(payload: SendEmailRequest):
    try:
        google_send_email(
            to=payload.to,
            subject=payload.subject,
            body=payload.body,
        )
        return {"status": "sent"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search-emails")
def search_emails_endpoint(query: str):
    try:
        logger.info(f"Searching emails with query: {query}")
        messages = google_search_emails(query)
        logger.info(f"Found {len(messages)} emails")
        return {"messages": messages}
    except Exception as e:
        logger.error(f"Error searching emails: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/emails")
def list_emails_endpoint(limit: int = 10):
    try:
        logger.info(f"Fetching last {limit} emails")
        emails = google_list_emails(limit)
        logger.info(f"Retrieved {len(emails)} emails")
        return {"emails": emails}
    except Exception as e:
        logger.error(f"Error listing emails: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/email/{message_id}")
def delete_email_endpoint(message_id: str):
    try:
        logger.info(f"Attempting to delete email: {message_id}")
        google_delete_email(message_id)
        logger.info(f"Successfully deleted email: {message_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting email {message_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calendar-event")
def calendar_event_endpoint(payload: CalendarEventRequest):
    try:
        event = google_create_calendar_event(
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


@router.delete("/calendar-event/{event_id}")
def delete_calendar_event_endpoint(event_id: str):
    try:
        google_delete_calendar_event(event_id)
        return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# Google Drive Endpoints
# =========================

@router.get("/drive/files")
def list_drive_files_endpoint(query: Optional[str] = None, limit: int = 10):
    """List files in Google Drive."""
    try:
        logger.info(f"Listing drive files with query: {query}, limit: {limit}")
        files = google_list_drive_files(query=query, max_results=limit)
        logger.info(f"Found {len(files)} files")
        return {"files": files}
    except Exception as e:
        logger.error(f"Error listing drive files: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/drive/search")
def search_drive_files_endpoint(query: str, limit: int = 10):
    """Search files in Google Drive."""
    try:
        logger.info(f"Searching drive files with query: {query}")
        files = google_search_drive_files(query=query, max_results=limit)
        logger.info(f"Found {len(files)} files")
        return {"files": files}
    except Exception as e:
        logger.error(f"Error searching drive files: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/drive/file/{file_id}")
def get_drive_file_endpoint(file_id: str):
    """Get file metadata from Google Drive."""
    try:
        logger.info(f"Getting file metadata: {file_id}")
        file = google_get_drive_file(file_id)
        logger.info(f"Retrieved file: {file.get('name')}")
        return {"file": file}
    except Exception as e:
        logger.error(f"Error getting drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/drive/file/{file_id}/read")
def read_drive_file_endpoint(file_id: str):
    """Read file content from Google Drive."""
    try:
        logger.info(f"Reading file content: {file_id}")
        content = google_read_drive_file(file_id)
        logger.info(f"Successfully read file: {file_id}")
        return {"content": content}
    except Exception as e:
        logger.error(f"Error reading drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/drive/file")
def create_drive_file_endpoint(payload: DriveFileRequest):
    """Create a file in Google Drive."""
    try:
        logger.info(f"Creating drive file: {payload.name}")
        file = google_create_drive_file(
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


@router.post("/drive/folder")
def create_drive_folder_endpoint(payload: DriveFolderRequest):
    """Create a folder in Google Drive."""
    try:
        logger.info(f"Creating drive folder: {payload.name}")
        folder = google_create_drive_folder(
            name=payload.name,
            parent_folder_id=payload.parent_folder_id,
        )
        logger.info(f"Created folder: {folder.get('name')}")
        return {"folder": folder}
    except Exception as e:
        logger.error(f"Error creating drive folder: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/drive/file/{file_id}")
def update_drive_file_endpoint(file_id: str, payload: DriveFileRequest):
    """Update file content in Google Drive."""
    try:
        logger.info(f"Updating drive file: {file_id}")
        file = google_update_drive_file(file_id=file_id, content=payload.content)
        logger.info(f"Updated file: {file.get('name')}")
        return {"file": file}
    except Exception as e:
        logger.error(f"Error updating drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/drive/file/{file_id}")
def delete_drive_file_endpoint(file_id: str):
    """Delete a file from Google Drive."""
    try:
        logger.info(f"Deleting drive file: {file_id}")
        google_delete_drive_file(file_id)
        logger.info(f"Successfully deleted file: {file_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/drive/file/{file_id}/share")
def share_drive_file_endpoint(file_id: str, email: str, role: str = "reader"):
    """Share a Google Drive file with someone."""
    try:
        logger.info(f"Sharing drive file {file_id} with {email} as {role}")
        result = google_share_drive_file(file_id=file_id, email=email, role=role)
        logger.info(f"Successfully shared file with {email}")
        return {"status": "shared", "permission": result}
    except Exception as e:
        logger.error(f"Error sharing drive file {file_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
