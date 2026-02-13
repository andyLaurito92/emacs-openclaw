"""Tool Registry - Centralized metadata about available tools

This keeps /tools endpoint clean by avoiding a giant dictionary in server.py
"""

TOOLS_REGISTRY = {
    "neo4j": [
        {
            "name": "query",
            "endpoint": "/neo4j/query",
            "method": "POST",
            "description": "Execute a single Cypher query",
            "parameters": {
                "query": "string (Cypher query)",
                "parameters": "object (query parameters, optional)",
            },
        },
        {
            "name": "batch",
            "endpoint": "/neo4j/batch",
            "method": "POST",
            "description": "Execute multiple Cypher statements in a single atomic transaction",
            "parameters": {
                "statements": "array of {statement: string, parameters: object}",
            },
        },
        {
            "name": "stats",
            "endpoint": "/neo4j/stats",
            "method": "GET",
            "description": "Get graph statistics (node and relationship counts)",
            "parameters": {},
        },
        {
            "name": "health",
            "endpoint": "/neo4j/health",
            "method": "GET",
            "description": "Check Neo4j connection status",
            "parameters": {},
        },
    ],
    "google": [
        {
            "name": "send_email",
            "endpoint": "/google/send-email",
            "method": "POST",
            "description": "Send an email via Gmail",
            "parameters": {
                "to": "string (email address)",
                "subject": "string",
                "body": "string",
            },
        },
        {
            "name": "search_emails",
            "endpoint": "/google/search-emails",
            "method": "GET",
            "description": "Search emails using Gmail query syntax",
            "parameters": {"query": "string (e.g., 'from:user@example.com')"},
        },
        {
            "name": "list_emails",
            "endpoint": "/google/emails",
            "method": "GET",
            "description": "List recent emails",
            "parameters": {"limit": "integer (default: 10)"},
        },
        {
            "name": "delete_email",
            "endpoint": "/google/email/{message_id}",
            "method": "DELETE",
            "description": "Delete (trash) an email by message ID",
            "parameters": {"message_id": "string (email ID)"},
        },
        {
            "name": "create_calendar_event",
            "endpoint": "/google/calendar-event",
            "method": "POST",
            "description": "Create a Google Calendar event",
            "parameters": {
                "summary": "string",
                "start_iso": "string (ISO 8601, e.g., '2026-02-13T14:00:00Z')",
                "end_iso": "string (ISO 8601)",
                "description": "string (optional)",
                "timezone": "string (optional, e.g., 'Europe/Madrid')",
                "attendees": "array of emails (optional)",
            },
        },
        {
            "name": "delete_calendar_event",
            "endpoint": "/google/calendar-event/{event_id}",
            "method": "DELETE",
            "description": "Delete a Google Calendar event",
            "parameters": {"event_id": "string (event ID)"},
        },
        {
            "name": "list_drive_files",
            "endpoint": "/google/drive/files",
            "method": "GET",
            "description": "List files in Google Drive",
            "parameters": {"limit": "integer (default: 10)"},
        },
        {
            "name": "search_drive_files",
            "endpoint": "/google/drive/search",
            "method": "GET",
            "description": "Search Google Drive files",
            "parameters": {"query": "string (search query)"},
        },
        {
            "name": "read_drive_file",
            "endpoint": "/google/drive/file/{file_id}/read",
            "method": "GET",
            "description": "Read content of a Google Drive file",
            "parameters": {"file_id": "string (file ID)"},
        },
        {
            "name": "create_drive_file",
            "endpoint": "/google/drive/file",
            "method": "POST",
            "description": "Create a file in Google Drive",
            "parameters": {
                "name": "string (file name)",
                "content": "string (file content)",
            },
        },
    ],
    "microsoft": [
        {
            "name": "list_emails",
            "endpoint": "/microsoft/emails",
            "method": "GET",
            "description": "List emails from Microsoft Exchange",
            "parameters": {"limit": "integer (default: 10)"},
        },
        {
            "name": "search_emails",
            "endpoint": "/microsoft/search-emails",
            "method": "GET",
            "description": "Search emails in Microsoft Exchange",
            "parameters": {"query": "string (search query)"},
        },
        {
            "name": "send_email",
            "endpoint": "/microsoft/send-email",
            "method": "POST",
            "description": "Send an email via Microsoft Exchange",
            "parameters": {
                "to": "string (email address)",
                "subject": "string",
                "body": "string",
            },
        },
        {
            "name": "delete_email",
            "endpoint": "/microsoft/email/{message_id}",
            "method": "DELETE",
            "description": "Delete an email from Microsoft Exchange",
            "parameters": {"message_id": "string (email ID)"},
        },
        {
            "name": "list_calendar_events",
            "endpoint": "/microsoft/calendar-events",
            "method": "GET",
            "description": "List calendar events from Microsoft Exchange",
            "parameters": {"limit": "integer (default: 10)"},
        },
        {
            "name": "create_calendar_event",
            "endpoint": "/microsoft/calendar-event",
            "method": "POST",
            "description": "Create a calendar event in Microsoft Exchange",
            "parameters": {
                "subject": "string",
                "start_iso": "string (ISO 8601)",
                "end_iso": "string (ISO 8601)",
                "body": "string (optional)",
            },
        },
        {
            "name": "delete_calendar_event",
            "endpoint": "/microsoft/calendar-event/{event_id}",
            "method": "DELETE",
            "description": "Delete a calendar event from Microsoft Exchange",
            "parameters": {"event_id": "string (event ID)"},
        },
    ],
    "emacs": [
        {
            "name": "list_buffers",
            "endpoint": "/emacs/buffers",
            "method": "GET",
            "description": "List open Emacs buffers",
            "parameters": {},
        },
        {
            "name": "create_buffer",
            "endpoint": "/emacs/buffer",
            "method": "POST",
            "description": "Create a new Emacs buffer",
            "parameters": {
                "buffer_name": "string (buffer name)",
            },
        },
        {
            "name": "get_buffer_content",
            "endpoint": "/emacs/buffer/{buffer_name}/content",
            "method": "GET",
            "description": "Get content of an Emacs buffer",
            "parameters": {"buffer_name": "string (buffer name)"},
        },
        {
            "name": "set_buffer_content",
            "endpoint": "/emacs/buffer/{buffer_name}/content",
            "method": "PUT",
            "description": "Set (replace) the entire content of a buffer",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "content": "string (new buffer content)",
            },
        },
        {
            "name": "delete_buffer",
            "endpoint": "/emacs/buffer/{buffer_name}",
            "method": "DELETE",
            "description": "Delete an Emacs buffer",
            "parameters": {"buffer_name": "string (buffer name)"},
        },
        {
            "name": "append_buffer_content",
            "endpoint": "/emacs/buffer/{buffer_name}/append",
            "method": "POST",
            "description": "Append text to the end of a buffer",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "text": "string (text to append)",
            },
        },
        {
            "name": "get_buffer_info",
            "endpoint": "/emacs/buffer/{buffer_name}/info",
            "method": "GET",
            "description": "Get metadata about a buffer (size, mode, modified status)",
            "parameters": {
                "buffer_name": "string (buffer name)",
            },
        },
        {
            "name": "get_buffer_region",
            "endpoint": "/emacs/buffer/{buffer_name}/region",
            "method": "GET",
            "description": "Get a region of text from a buffer by character position range",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "start": "integer (0-indexed start position, default: 0)",
                "end": "integer (0-indexed end position, exclusive)",
            },
        },
        {
            "name": "set_buffer_region",
            "endpoint": "/emacs/buffer/{buffer_name}/region",
            "method": "PUT",
            "description": "Replace a region of text in a buffer",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "start": "integer (0-indexed start position, default: 0)",
                "end": "integer (0-indexed end position, exclusive)",
                "content": "string (new content for the region)",
            },
        },
        {
            "name": "buffer_replace",
            "endpoint": "/emacs/buffer/{buffer_name}/replace",
            "method": "POST",
            "description": "Search and replace text in a buffer (single or all occurrences)",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "find": "string (text to find)",
                "replace": "string (replacement text)",
                "all": "boolean (replace all occurrences if true, else first only)",
            },
        },
        {
            "name": "set_buffer_mode",
            "endpoint": "/emacs/buffer/{buffer_name}/mode",
            "method": "POST",
            "description": "Set the major mode of a buffer (changes syntax highlighting and behavior)",
            "parameters": {
                "buffer_name": "string (buffer name)",
                "mode": "string (mode name, e.g., 'text-mode', 'org-mode', 'markdown-mode')",
            },
        },
        {
            "name": "eval_elisp",
            "endpoint": "/emacs/eval",
            "method": "POST",
            "description": "Evaluate arbitrary Emacs Lisp code",
            "parameters": {
                "code": "string (Emacs Lisp expression)",
            },
        },
    ],
}


def get_all_tools():
    """Flatten the registry into a single tools list."""
    tools = []
    for provider, provider_tools in TOOLS_REGISTRY.items():
        for tool in provider_tools:
            tools.append({"provider": provider, **tool})
    return tools


def get_providers():
    """Get list of all providers."""
    return list(TOOLS_REGISTRY.keys())
