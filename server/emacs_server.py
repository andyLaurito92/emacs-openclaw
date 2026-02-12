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
