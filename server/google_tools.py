import base64
from email.message import EmailMessage
from typing import Optional, List


from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

# ---- Config ----
TOKEN_FILE = "token.json"
GMAIL_API = ("gmail", "v1")
CALENDAR_API = ("calendar", "v3")
DRIVE_API = ("drive", "v3")


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


def google_send_email(
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

    service.users().messages().send(userId="me", body={"raw": raw}).execute()


def google_search_emails(query: str) -> list:
    """
    Search emails by query string.
    Returns a list of message IDs.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = (
        service.users()
        .messages()
        .list(
            userId="me",
            q=query,
        )
        .execute()
    )

    return results.get("messages", [])


def google_get_email(message_id: str) -> dict:
    """
    Get full email details by message ID, including body and unsubscribe link.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    msg = (
        service.users()
        .messages()
        .get(
            userId="me",
            id=message_id,
            format="full",
        )
        .execute()
    )

    headers = msg["payload"]["headers"]
    subject = next((h["value"] for h in headers if h["name"] == "Subject"), "")
    from_addr = next((h["value"] for h in headers if h["name"] == "From"), "")
    date = next((h["value"] for h in headers if h["name"] == "Date"), "")
    list_unsubscribe = next((h["value"] for h in headers if h["name"] == "List-Unsubscribe"), "")

    # Extract body
    body = ""
    payload = msg.get("payload", {})
    
    if "parts" in payload:
        # Multipart message
        for part in payload["parts"]:
            if part["mimeType"] == "text/plain" or part["mimeType"] == "text/html":
                if "data" in part["body"]:
                    body = base64.urlsafe_b64decode(part["body"]["data"]).decode("utf-8", errors="ignore")
                    break
    elif "body" in payload and "data" in payload["body"]:
        # Simple message
        body = base64.urlsafe_b64decode(payload["body"]["data"]).decode("utf-8", errors="ignore")

    return {
        "id": message_id,
        "subject": subject,
        "from": from_addr,
        "date": date,
        "body": body,
        "list_unsubscribe": list_unsubscribe,
    }


def google_list_emails(max_results: int = 10) -> list:
    """
    Get the last N emails (unread and read).
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = (
        service.users()
        .messages()
        .list(
            userId="me",
            maxResults=max_results,
        )
        .execute()
    )

    messages = results.get("messages", [])
    return [google_get_email(msg["id"]) for msg in messages]


def google_delete_email(message_id: str) -> None:
    """
    Delete an email by message ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().messages().trash(
        userId="me",
        id=message_id,
    ).execute()


def google_batch_delete_emails(message_ids: List[str]) -> None:
    """
    Batch delete multiple emails by message IDs.
    Much faster than deleting one-by-one.
    
    Note: Provides no guarantees that messages were not already deleted.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().messages().batchDelete(
        userId="me",
        body={"ids": message_ids},
    ).execute()


# =========================
# Google Calendar
# =========================


def google_create_calendar_event(
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

    created = (
        service.events()
        .insert(
            calendarId="primary",
            body=event,
            sendUpdates="all",  # ← THIS sends the invites
        )
        .execute()
    )

    return {
        "id": created.get("id"),
        "htmlLink": created.get("htmlLink"),
    }


def google_delete_calendar_event(event_id: str) -> None:
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


# =========================
# Google Drive
# =========================


def google_list_drive_files(
    query: Optional[str] = None,
    max_results: int = 10,
    order_by: str = "modifiedTime desc",
) -> list:
    """
    List files in Google Drive.

    query: Optional filter (e.g., "name contains 'document'", "mimeType='application/vnd.google-apps.folder'")
    max_results: Maximum number of files to return
    order_by: How to sort results (e.g., "modifiedTime desc", "name asc")
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    q = query if query else "trashed=false"

    results = (
        service.files()
        .list(
            q=q,
            spaces="drive",
            fields="files(id, name, mimeType, modifiedTime, owners, webViewLink, size)",
            pageSize=max_results,
            orderBy=order_by,
        )
        .execute()
    )

    return results.get("files", [])


def google_search_drive_files(
    query: str,
    max_results: int = 10,
) -> list:
    """
    Search files in Google Drive by name or content.
    """
    return google_list_drive_files(query=query, max_results=max_results)


def google_get_drive_file(file_id: str) -> dict:
    """
    Get file metadata by ID.
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    file = (
        service.files()
        .get(
            fileId=file_id,
            fields="id, name, mimeType, modifiedTime, owners, webViewLink, size, description",
        )
        .execute()
    )

    return file


def google_read_drive_file(file_id: str) -> str:
    """
    Read file content from Google Drive.
    Supports Google Docs (converts to plain text), text files, and PDFs.
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    # Get file metadata first
    file = (
        service.files()
        .get(
            fileId=file_id,
            fields="id, name, mimeType",
        )
        .execute()
    )

    mime_type = file.get("mimeType", "")

    # Handle Google Docs
    if "application/vnd.google-apps.document" in mime_type:
        # Export as plain text
        content = (
            service.files()
            .export(
                fileId=file_id,
                mimeType="text/plain",
            )
            .execute()
        )
        return content.decode("utf-8") if isinstance(content, bytes) else content

    # Handle Google Sheets
    elif "application/vnd.google-apps.spreadsheet" in mime_type:
        # Export as CSV
        content = (
            service.files()
            .export(
                fileId=file_id,
                mimeType="text/csv",
            )
            .execute()
        )
        return content.decode("utf-8") if isinstance(content, bytes) else content

    # Handle plain text and other files
    elif mime_type.startswith("text/"):
        content = service.files().get_media(fileId=file_id).execute()
        return content.decode("utf-8") if isinstance(content, bytes) else content

    else:
        raise ValueError(f"Unsupported file type: {mime_type}")


def google_create_drive_file(
    name: str,
    content: str,
    parent_folder_id: Optional[str] = None,
    mime_type: str = "text/plain",
) -> dict:
    """
    Create a file in Google Drive.

    mime_type examples:
    - "text/plain" for text files
    - "application/vnd.google-apps.document" for Google Docs
    - "application/vnd.google-apps.spreadsheet" for Google Sheets
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    file_metadata = {
        "name": name,
        "mimeType": mime_type,
    }

    if parent_folder_id:
        file_metadata["parents"] = [parent_folder_id]

    media = None
    if content and mime_type == "text/plain":
        from googleapiclient.http import MediaInMemoryUpload

        media = MediaInMemoryUpload(content.encode("utf-8"), mimetype=mime_type)

    created = (
        service.files()
        .create(
            body=file_metadata,
            media_body=media,
            fields="id, name, webViewLink",
        )
        .execute()
    )

    return {
        "id": created.get("id"),
        "name": created.get("name"),
        "webViewLink": created.get("webViewLink"),
    }


def google_create_drive_folder(
    name: str,
    parent_folder_id: Optional[str] = None,
) -> dict:
    """
    Create a folder in Google Drive.
    """
    return google_create_drive_file(
        name=name,
        content="",
        parent_folder_id=parent_folder_id,
        mime_type="application/vnd.google-apps.folder",
    )


def google_update_drive_file(
    file_id: str,
    content: str,
) -> dict:
    """
    Update file content in Google Drive.
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    from googleapiclient.http import MediaInMemoryUpload

    media = MediaInMemoryUpload(content.encode("utf-8"), mimetype="text/plain")

    updated = (
        service.files()
        .update(
            fileId=file_id,
            media_body=media,
            fields="id, name, webViewLink",
        )
        .execute()
    )

    return {
        "id": updated.get("id"),
        "name": updated.get("name"),
        "webViewLink": updated.get("webViewLink"),
    }


def google_delete_drive_file(file_id: str) -> None:
    """
    Delete a file from Google Drive (permanent deletion).
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    service.files().delete(fileId=file_id).execute()


def google_share_drive_file(
    file_id: str,
    email: str,
    role: str = "reader",
) -> dict:
    """
    Share a Google Drive file with someone.

    role options: "owner", "organizer", "fileOrganizer", "writer", "commenter", "reader"
    """
    creds = _load_creds()
    service = build(*DRIVE_API, credentials=creds)

    permission = {
        "type": "user",
        "role": role,
        "emailAddress": email,
    }

    result = (
        service.permissions()
        .create(
            fileId=file_id,
            body=permission,
            fields="id, emailAddress, role, type",
        )
        .execute()
    )

    return result


# =========================
# Gmail Labels
# =========================


def google_create_label(
    name: str,
    label_list_visibility: str = "labelShow",
    message_list_visibility: str = "show",
) -> dict:
    """
    Create a Gmail label.
    
    label_list_visibility: "labelShow" or "labelHide"
    message_list_visibility: "show" or "hide"
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    label_obj = {
        "name": name,
        "labelListVisibility": label_list_visibility,
        "messageListVisibility": message_list_visibility,
    }

    result = (
        service.users()
        .labels()
        .create(
            userId="me",
            body=label_obj,
        )
        .execute()
    )

    return {
        "id": result.get("id"),
        "name": result.get("name"),
    }


def google_list_labels() -> list:
    """
    List all Gmail labels.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = (
        service.users()
        .labels()
        .list(userId="me")
        .execute()
    )

    return results.get("labels", [])


def google_get_label(label_id: str) -> dict:
    """
    Get a specific label by ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    label = (
        service.users()
        .labels()
        .get(userId="me", id=label_id)
        .execute()
    )

    return label


def google_delete_label(label_id: str) -> None:
    """
    Delete a Gmail label by ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().labels().delete(userId="me", id=label_id).execute()


def google_apply_label(message_id: str, label_id: str) -> None:
    """
    Apply a label to an email message.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().messages().modify(
        userId="me",
        id=message_id,
        body={"addLabelIds": [label_id]},
    ).execute()


def google_remove_label(message_id: str, label_id: str) -> None:
    """
    Remove a label from an email message.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().messages().modify(
        userId="me",
        id=message_id,
        body={"removeLabelIds": [label_id]},
    ).execute()


def google_apply_label_batch(message_ids: List[str], label_id: str) -> None:
    """
    Apply a label to multiple email messages.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    for msg_id in message_ids:
        service.users().messages().modify(
            userId="me",
            id=msg_id,
            body={"addLabelIds": [label_id]},
        ).execute()


# =========================
# Gmail Filters
# =========================


def google_create_filter(
    criteria: dict,
    action: dict,
) -> dict:
    """
    Create a Gmail filter.
    
    criteria example: {
        "from": "sender@example.com",
        "to": "recipient@example.com",
        "subject": "keywords",
        "hasAttachment": True,
        "excludeChats": False,
    }
    
    action example: {
        "addLabelIds": ["label_id"],
        "removeLabelIds": [],
        "archive": False,
        "markAsRead": False,
        "neverSpam": False,
        "skipInbox": False,
        "delete": False,
    }
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    filter_obj = {
        "criteria": criteria,
        "action": action,
    }

    result = (
        service.users()
        .settings()
        .filters()
        .create(userId="me", body=filter_obj)
        .execute()
    )

    return {
        "id": result.get("id"),
        "criteria": result.get("criteria"),
        "action": result.get("action"),
    }


def google_list_filters() -> list:
    """
    List all Gmail filters.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    results = (
        service.users()
        .settings()
        .filters()
        .list(userId="me")
        .execute()
    )

    return results.get("filter", [])


def google_get_filter(filter_id: str) -> dict:
    """
    Get a specific filter by ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    filter_obj = (
        service.users()
        .settings()
        .filters()
        .get(userId="me", id=filter_id)
        .execute()
    )

    return filter_obj


def google_delete_filter(filter_id: str) -> None:
    """
    Delete a Gmail filter by ID.
    """
    creds = _load_creds()
    service = build(*GMAIL_API, credentials=creds)

    service.users().settings().filters().delete(userId="me", id=filter_id).execute()
