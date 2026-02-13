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
    google_batch_delete_emails,
    google_get_email,
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
    google_create_label,
    google_list_labels,
    google_get_label,
    google_delete_label,
    google_apply_label,
    google_remove_label,
    google_apply_label_batch,
    google_create_filter,
    google_list_filters,
    google_get_filter,
    google_delete_filter,
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


@router.get("/email/{message_id}")
def get_email_endpoint(message_id: str):
    try:
        logger.info(f"Fetching email content: {message_id}")
        email = google_get_email(message_id)
        logger.info(f"Retrieved email: {email.get('subject')}")
        return {"email": email}
    except Exception as e:
        logger.error(f"Error fetching email {message_id}: {str(e)}", exc_info=True)
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


class BatchDeleteEmailsRequest(BaseModel):
    message_ids: List[str]


@router.post("/emails/batch-delete")
def batch_delete_emails_endpoint(payload: BatchDeleteEmailsRequest):
    """Batch delete multiple emails. Much faster than deleting one-by-one."""
    try:
        logger.info(f"Batch deleting {len(payload.message_ids)} emails")
        google_batch_delete_emails(payload.message_ids)
        logger.info(f"Successfully batch deleted {len(payload.message_ids)} emails")
        return {"status": "deleted", "count": len(payload.message_ids)}
    except Exception as e:
        logger.error(f"Error batch deleting emails: {str(e)}", exc_info=True)
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


# =========================
# Gmail Labels
# =========================


class LabelRequest(BaseModel):
    name: str
    label_list_visibility: Optional[str] = "labelShow"
    message_list_visibility: Optional[str] = "show"


class ApplyLabelRequest(BaseModel):
    message_id: str
    label_id: str


class ApplyLabelBatchRequest(BaseModel):
    message_ids: List[str]
    label_id: str


@router.post("/labels")
def create_label_endpoint(payload: LabelRequest):
    """Create a new Gmail label."""
    try:
        logger.info(f"Creating label: {payload.name}")
        label = google_create_label(
            name=payload.name,
            label_list_visibility=payload.label_list_visibility,
            message_list_visibility=payload.message_list_visibility,
        )
        logger.info(f"Created label: {label.get('name')}")
        return {"label": label}
    except Exception as e:
        logger.error(f"Error creating label: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/labels")
def list_labels_endpoint():
    """List all Gmail labels."""
    try:
        logger.info("Listing all labels")
        labels = google_list_labels()
        logger.info(f"Found {len(labels)} labels")
        return {"labels": labels}
    except Exception as e:
        logger.error(f"Error listing labels: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/labels/{label_id}")
def get_label_endpoint(label_id: str):
    """Get a specific Gmail label."""
    try:
        logger.info(f"Getting label: {label_id}")
        label = google_get_label(label_id)
        logger.info(f"Retrieved label: {label.get('name')}")
        return {"label": label}
    except Exception as e:
        logger.error(f"Error getting label {label_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/labels/{label_id}")
def delete_label_endpoint(label_id: str):
    """Delete a Gmail label."""
    try:
        logger.info(f"Deleting label: {label_id}")
        google_delete_label(label_id)
        logger.info(f"Successfully deleted label: {label_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting label {label_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/email/{message_id}/label/{label_id}")
def apply_label_endpoint(message_id: str, label_id: str):
    """Apply a label to an email message."""
    try:
        logger.info(f"Applying label {label_id} to email {message_id}")
        google_apply_label(message_id, label_id)
        logger.info(f"Successfully applied label to email")
        return {"status": "applied"}
    except Exception as e:
        logger.error(f"Error applying label: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/email/{message_id}/label/{label_id}")
def remove_label_endpoint(message_id: str, label_id: str):
    """Remove a label from an email message."""
    try:
        logger.info(f"Removing label {label_id} from email {message_id}")
        google_remove_label(message_id, label_id)
        logger.info(f"Successfully removed label from email")
        return {"status": "removed"}
    except Exception as e:
        logger.error(f"Error removing label: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/emails/label-batch")
def apply_label_batch_endpoint(payload: ApplyLabelBatchRequest):
    """Apply a label to multiple email messages."""
    try:
        logger.info(f"Applying label {payload.label_id} to {len(payload.message_ids)} emails")
        google_apply_label_batch(payload.message_ids, payload.label_id)
        logger.info(f"Successfully applied label to {len(payload.message_ids)} emails")
        return {"status": "applied", "count": len(payload.message_ids)}
    except Exception as e:
        logger.error(f"Error applying label batch: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# Gmail Filters
# =========================


class FilterCriteria(BaseModel):
    from_address: Optional[str] = None
    to: Optional[str] = None
    subject: Optional[str] = None
    has_attachment: Optional[bool] = None
    exclude_chats: Optional[bool] = None


class FilterAction(BaseModel):
    add_label_ids: Optional[List[str]] = None
    remove_label_ids: Optional[List[str]] = None
    archive: Optional[bool] = None
    mark_as_read: Optional[bool] = None
    never_spam: Optional[bool] = None
    skip_inbox: Optional[bool] = None
    delete: Optional[bool] = None


class CreateFilterRequest(BaseModel):
    criteria: FilterCriteria
    action: FilterAction


@router.post("/filters")
def create_filter_endpoint(payload: CreateFilterRequest):
    """Create a Gmail filter."""
    try:
        # Convert Pydantic models to dicts, filtering out None values
        criteria = {
            "from": payload.criteria.from_address,
            "to": payload.criteria.to,
            "subject": payload.criteria.subject,
            "hasAttachment": payload.criteria.has_attachment,
            "excludeChats": payload.criteria.exclude_chats,
        }
        criteria = {k: v for k, v in criteria.items() if v is not None}

        action = {
            "addLabelIds": payload.action.add_label_ids or [],
            "removeLabelIds": payload.action.remove_label_ids or [],
            "archive": payload.action.archive or False,
            "markAsRead": payload.action.mark_as_read or False,
            "neverSpam": payload.action.never_spam or False,
            "skipInbox": payload.action.skip_inbox or False,
            "delete": payload.action.delete or False,
        }

        logger.info(f"Creating filter with criteria: {criteria}")
        filter_obj = google_create_filter(criteria, action)
        logger.info(f"Created filter: {filter_obj.get('id')}")
        return {"filter": filter_obj}
    except Exception as e:
        logger.error(f"Error creating filter: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/filters")
def list_filters_endpoint():
    """List all Gmail filters."""
    try:
        logger.info("Listing all filters")
        filters = google_list_filters()
        logger.info(f"Found {len(filters)} filters")
        return {"filters": filters}
    except Exception as e:
        logger.error(f"Error listing filters: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/filters/{filter_id}")
def get_filter_endpoint(filter_id: str):
    """Get a specific Gmail filter."""
    try:
        logger.info(f"Getting filter: {filter_id}")
        filter_obj = google_get_filter(filter_id)
        logger.info(f"Retrieved filter: {filter_obj.get('id')}")
        return {"filter": filter_obj}
    except Exception as e:
        logger.error(f"Error getting filter {filter_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/filters/{filter_id}")
def delete_filter_endpoint(filter_id: str):
    """Delete a Gmail filter."""
    try:
        logger.info(f"Deleting filter: {filter_id}")
        google_delete_filter(filter_id)
        logger.info(f"Successfully deleted filter: {filter_id}")
        return {"status": "deleted"}
    except Exception as e:
        logger.error(f"Error deleting filter {filter_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
