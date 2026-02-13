"""
FastAPI router for Emacs buffer operations.
Provides HTTP endpoints for manipulating Emacs buffers via emacsclient.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
import logging

from emacs_tools import (
    emacs_list_buffers,
    emacs_create_buffer,
    emacs_get_buffer_content,
    emacs_set_buffer_content,
    emacs_delete_buffer,
    emacs_append_buffer_content,
    emacs_get_buffer_info,
    emacs_get_buffer_region,
    emacs_set_buffer_region,
    emacs_buffer_replace,
    emacs_set_buffer_mode,
    emacs_eval_elisp,
)

logger = logging.getLogger(__name__)

# Create router with /emacs prefix
router = APIRouter(prefix="/emacs", tags=["emacs"])


# =========================
# Schemas
# =========================


class CreateBufferRequest(BaseModel):
    name: str


class SetBufferContentRequest(BaseModel):
    content: str


class BufferNameRequest(BaseModel):
    name: str


class AppendBufferContentRequest(BaseModel):
    content: str


class SetBufferRegionRequest(BaseModel):
    content: str


class BufferReplaceRequest(BaseModel):
    find: str
    replace: str
    all: bool = False


class SetBufferModeRequest(BaseModel):
    mode: str


class EvalElispRequest(BaseModel):
    code: str


# =========================
# Endpoints
# =========================


@router.get("/buffers")
def list_buffers_endpoint():
    """
    List all visible buffer names in Emacs.
    
    Returns a list of buffer names (excluding internal buffers).
    """
    try:
        logger.info("Listing Emacs buffers")
        buffers = emacs_list_buffers()
        logger.info(f"Found {len(buffers)} buffers")
        return {"buffers": buffers}
    except Exception as e:
        logger.error(f"Error listing buffers: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buffer")
def create_buffer_endpoint(payload: CreateBufferRequest):
    """
    Create a new buffer in Emacs.
    
    Args:
        name: Name for the new buffer
        
    Returns:
        The name of the created buffer
    """
    try:
        logger.info(f"Creating buffer: {payload.name}")
        buffer_name = emacs_create_buffer(payload.name)
        logger.info(f"Buffer created: {buffer_name}")
        return {"status": "created", "buffer_name": buffer_name}
    except Exception as e:
        logger.error(f"Error creating buffer: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/buffer/{buffer_name}/content")
def get_buffer_content_endpoint(buffer_name: str):
    """
    Get the content of a buffer.
    
    Args:
        buffer_name: Name of the buffer to read
        
    Returns:
        The buffer's content as a string
    """
    try:
        logger.info(f"Getting content of buffer: {buffer_name}")
        content = emacs_get_buffer_content(buffer_name)
        logger.info(f"Retrieved {len(content)} characters from buffer")
        return {"buffer_name": buffer_name, "content": content}
    except Exception as e:
        logger.error(f"Error getting buffer content: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/buffer/{buffer_name}/content")
def set_buffer_content_endpoint(buffer_name: str, payload: SetBufferContentRequest):
    """
    Set the content of a buffer, replacing all existing content.
    
    Args:
        buffer_name: Name of the buffer to modify
        payload: Request containing the new content for the buffer
        
    Returns:
        Success status
    """
    try:
        logger.info(f"Setting content of buffer: {buffer_name}")
        success = emacs_set_buffer_content(buffer_name, payload.content)
        if success:
            logger.info(f"Buffer content updated successfully")
            return {"status": "success", "buffer_name": buffer_name}
        else:
            raise HTTPException(status_code=500, detail="Failed to set buffer content")
    except Exception as e:
        logger.error(f"Error setting buffer content: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/buffer/{buffer_name}")
def delete_buffer_endpoint(buffer_name: str):
    """
    Delete a buffer.
    
    Args:
        buffer_name: Name of the buffer to delete
        
    Returns:
        Success status and whether buffer was deleted
    """
    try:
        logger.info(f"Deleting buffer: {buffer_name}")
        deleted = emacs_delete_buffer(buffer_name)
        if deleted:
            logger.info(f"Buffer deleted successfully")
            return {"status": "deleted", "buffer_name": buffer_name}
        else:
            logger.info(f"Buffer did not exist")
            return {"status": "not_found", "buffer_name": buffer_name}
    except Exception as e:
        logger.error(f"Error deleting buffer: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# =========================
# New Endpoints
# =========================


@router.post("/buffer/{buffer_name}/append")
def append_buffer_content_endpoint(buffer_name: str, payload: AppendBufferContentRequest):
    """
    Append content to a buffer without replacing existing content.
    
    Args:
        buffer_name: Name of the buffer to append to
        payload: Request containing the content to append
        
    Returns:
        Success status
    """
    try:
        logger.info(f"Appending to buffer: {buffer_name}")
        success = emacs_append_buffer_content(buffer_name, payload.content)
        if success:
            logger.info(f"Content appended successfully")
            return {"status": "appended", "buffer_name": buffer_name}
        else:
            raise HTTPException(status_code=500, detail="Failed to append to buffer")
    except Exception as e:
        logger.error(f"Error appending to buffer: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/buffer/{buffer_name}/info")
def get_buffer_info_endpoint(buffer_name: str):
    """
    Get information about a buffer.
    
    Args:
        buffer_name: Name of the buffer
        
    Returns:
        Buffer info (line_count, char_count, modified, read_only, mode)
    """
    try:
        logger.info(f"Getting buffer info: {buffer_name}")
        info = emacs_get_buffer_info(buffer_name)
        logger.info(f"Retrieved buffer info for {buffer_name}")
        return {"buffer_name": buffer_name, "info": info}
    except Exception as e:
        logger.error(f"Error getting buffer info: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/buffer/{buffer_name}/region")
def get_buffer_region_endpoint(buffer_name: str, start: int = 0, end: int = None):
    """
    Get a region of text from a buffer.
    
    Args:
        buffer_name: Name of the buffer
        start: Start position (0-indexed)
        end: End position (0-indexed, exclusive). If None, get from start to end of buffer
        
    Returns:
        The text in that region
    """
    try:
        logger.info(f"Getting buffer region: {buffer_name}[{start}:{end}]")
        content = emacs_get_buffer_content(buffer_name)
        
        # If end is None, use full length
        if end is None:
            end = len(content)
        
        region_content = content[start:end]
        logger.info(f"Retrieved region ({len(region_content)} chars)")
        return {"buffer_name": buffer_name, "start": start, "end": end, "content": region_content}
    except Exception as e:
        logger.error(f"Error getting buffer region: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/buffer/{buffer_name}/region")
def set_buffer_region_endpoint(buffer_name: str, payload: SetBufferRegionRequest, start: int = 0, end: int = None):
    """
    Replace a region of text in a buffer.
    
    Args:
        buffer_name: Name of the buffer
        payload: Request containing the new content
        start: Start position (0-indexed)
        end: End position (0-indexed, exclusive)
        
    Returns:
        Success status
    """
    try:
        logger.info(f"Setting buffer region: {buffer_name}[{start}:{end}]")
        
        # Get current content
        content = emacs_get_buffer_content(buffer_name)
        
        # If end is None, use full length
        if end is None:
            end = len(content)
        
        # Replace the region
        new_content = content[:start] + payload.content + content[end:]
        success = emacs_set_buffer_content(buffer_name, new_content)
        
        if success:
            logger.info(f"Buffer region updated successfully")
            return {"status": "updated", "buffer_name": buffer_name, "start": start, "end": end}
        else:
            raise HTTPException(status_code=500, detail="Failed to set buffer region")
    except Exception as e:
        logger.error(f"Error setting buffer region: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buffer/{buffer_name}/replace")
def buffer_replace_endpoint(buffer_name: str, payload: BufferReplaceRequest):
    """
    Search and replace in a buffer.
    
    Args:
        buffer_name: Name of the buffer
        payload: Request with find, replace, and all_occurrences flag
        
    Returns:
        Replacement count and success status
    """
    try:
        logger.info(f"Replacing in buffer: {buffer_name}")
        
        # Get current content
        content = emacs_get_buffer_content(buffer_name)
        
        # Perform replacement
        if payload.all:
            new_content = content.replace(payload.find, payload.replace)
            count = content.count(payload.find)
        else:
            new_content = content.replace(payload.find, payload.replace, 1)
            count = 1 if payload.find in content else 0
        
        # Only update if something changed
        if content != new_content:
            success = emacs_set_buffer_content(buffer_name, new_content)
            if success:
                logger.info(f"Replaced {count} occurrences")
                return {"status": "replaced", "buffer_name": buffer_name, "count": count}
        
        return {"status": "replaced", "buffer_name": buffer_name, "count": 0}
    except Exception as e:
        logger.error(f"Error replacing in buffer: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buffer/{buffer_name}/mode")
def set_buffer_mode_endpoint(buffer_name: str, payload: SetBufferModeRequest):
    """
    Set the major mode of a buffer.
    
    Args:
        buffer_name: Name of the buffer
        payload: Request with mode name (e.g., "text-mode", "markdown-mode", "org-mode")
        
    Returns:
        Success status and new mode name
    """
    try:
        logger.info(f"Setting buffer mode: {buffer_name} -> {payload.mode}")
        new_mode = emacs_set_buffer_mode(buffer_name, payload.mode)
        logger.info(f"Buffer mode changed to: {new_mode}")
        return {"status": "mode_changed", "buffer_name": buffer_name, "mode": new_mode}
    except Exception as e:
        logger.error(f"Error setting buffer mode: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/eval")
def eval_elisp_endpoint(payload: EvalElispRequest):
    """
    Evaluate arbitrary Emacs Lisp code.
    
    Args:
        payload: Request containing the Elisp code
        
    Returns:
        The result of the evaluation
    """
    try:
        logger.info(f"Evaluating Elisp code: {payload.code[:50]}...")
        result = emacs_eval_elisp(payload.code)
        logger.info(f"Elisp evaluation completed")
        return {"status": "evaluated", "code": payload.code, "result": result}
    except Exception as e:
        logger.error(f"Error evaluating Elisp: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
