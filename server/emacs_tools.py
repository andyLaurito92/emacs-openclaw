"""
Emacs buffer manipulation tools using emacsclient.
Provides Python wrappers for Emacs buffer operations via emacsclient.
"""

import subprocess
import json
import logging
from typing import List, Optional

logger = logging.getLogger(__name__)


def _emacsclient_eval(elisp_expr: str) -> str:
    """
    Execute an Emacs Lisp expression via emacsclient and return the result.
    
    Args:
        elisp_expr: The Emacs Lisp expression to evaluate
        
    Returns:
        The output from emacsclient as a string
        
    Raises:
        RuntimeError: If emacsclient returns a non-zero exit code
    """
    cmd = ["emacsclient", "--eval", elisp_expr]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            # Return the raw output - caller handles parsing
            return result.stdout.strip()
        else:
            error_msg = result.stderr.strip() if result.stderr else "Unknown error"
            raise RuntimeError(f"emacsclient error: {error_msg}")
    except subprocess.TimeoutExpired:
        raise RuntimeError("emacsclient timed out after 5 seconds")
    except FileNotFoundError:
        raise RuntimeError("emacsclient not found. Is Emacs running in server mode?")


def _parse_elisp_string(elisp_output: str) -> str:
    """
    Parse a string from Emacs Lisp output.
    Handles quoted strings with proper escaping.
    
    Args:
        elisp_output: Raw output from emacsclient
        
    Returns:
        Parsed string value
    """
    # Remove surrounding quotes if present
    if elisp_output.startswith('"') and elisp_output.endswith('"'):
        # Handle Emacs Lisp string escaping
        content = elisp_output[1:-1]
        # Unescape common sequences
        content = content.replace('\\n', '\n')
        content = content.replace('\\t', '\t')
        content = content.replace('\\"', '"')
        content = content.replace('\\\\', '\\')
        return content
    return elisp_output


def _parse_elisp_list(elisp_output: str) -> List[str]:
    """
    Parse a list from Emacs Lisp output.
    
    Args:
        elisp_output: Raw output from emacsclient (e.g., '("buf1" "buf2")')
        
    Returns:
        Parsed list of strings
    """
    # Handle nil case
    if elisp_output == "nil":
        return []
    
    # Remove outer parentheses
    if elisp_output.startswith("(") and elisp_output.endswith(")"):
        content = elisp_output[1:-1].strip()
        if not content:
            return []
        
        # Simple parsing for quoted strings
        result = []
        in_string = False
        current = []
        i = 0
        while i < len(content):
            char = content[i]
            if char == '"' and (i == 0 or content[i-1] != '\\'):
                if in_string:
                    # End of string
                    result.append(_parse_elisp_string('"' + ''.join(current) + '"'))
                    current = []
                    in_string = False
                else:
                    # Start of string
                    in_string = True
            elif in_string:
                current.append(char)
            i += 1
        
        return result
    
    return [elisp_output]


def emacs_list_buffers() -> List[str]:
    """
    List all visible buffer names (excluding internal buffers starting with space).
    
    Returns:
        List of buffer names
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        output = _emacsclient_eval("(openclaw-list-buffer-names)")
        return _parse_elisp_list(output)
    except Exception as e:
        logger.error(f"Error listing buffers: {e}")
        raise


def emacs_create_buffer(buffer_name: str) -> str:
    """
    Create a new buffer with the given name.
    
    Args:
        buffer_name: Name for the new buffer
        
    Returns:
        The name of the created buffer
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = buffer_name.replace('\\', '\\\\').replace('"', '\\"')
        output = _emacsclient_eval(f'(openclaw-create-buffer "{escaped_name}")')
        return _parse_elisp_string(output)
    except Exception as e:
        logger.error(f"Error creating buffer '{buffer_name}': {e}")
        raise


def emacs_get_buffer_content(buffer_name: str) -> str:
    """
    Get the content of a buffer.
    
    Args:
        buffer_name: Name of the buffer to read
        
    Returns:
        The buffer's content as a string
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = buffer_name.replace('\\', '\\\\').replace('"', '\\"')
        output = _emacsclient_eval(f'(openclaw-get-buffer-content "{escaped_name}")')
        return _parse_elisp_string(output)
    except Exception as e:
        logger.error(f"Error getting content of buffer '{buffer_name}': {e}")
        raise


def emacs_set_buffer_content(buffer_name: str, content: str) -> bool:
    """
    Set the content of a buffer, replacing all existing content.
    
    Args:
        buffer_name: Name of the buffer to modify
        content: New content for the buffer
        
    Returns:
        True if successful
        
    Raises:
        RuntimeError: If emacsclient fails or buffer doesn't exist
    """
    try:
        # Escape both the buffer name and content for Elisp
        escaped_name = buffer_name.replace('\\', '\\\\').replace('"', '\\"')
        escaped_content = content.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
        output = _emacsclient_eval(f'(openclaw-set-buffer-content "{escaped_name}" "{escaped_content}")')
        return output == "t"
    except Exception as e:
        logger.error(f"Error setting content of buffer '{buffer_name}': {e}")
        raise


def emacs_delete_buffer(buffer_name: str) -> bool:
    """
    Delete a buffer.
    
    Args:
        buffer_name: Name of the buffer to delete
        
    Returns:
        True if buffer was deleted, False if it didn't exist
        
    Raises:
        RuntimeError: If emacsclient fails
    """
    try:
        # Escape the buffer name for Elisp
        escaped_name = buffer_name.replace('\\', '\\\\').replace('"', '\\"')
        output = _emacsclient_eval(f'(openclaw-delete-buffer "{escaped_name}")')
        return output == "t"
    except Exception as e:
        logger.error(f"Error deleting buffer '{buffer_name}': {e}")
        raise
